import base64, json, os
os.environ["HEARAWARE_SKIP_MODELS"] = "1"
import numpy as np
import pytest
from fastapi.testclient import TestClient

from app.ai.vad import SpeechSegmenter, is_speech, SAMPLE_RATE
from app.ai.yamnet import YamnetClassifier, direction_from_stereo, LABEL_MAP
from app.ai.yolo import YoloDetector, direction_from_bbox
from app.schemas import make_event
from app.pipeline import Session, Models, pcm16_to_float
from app import main


# ---------- event normalization ----------
def test_event_normalization_clamps_and_separates_confidences():
    e = make_event("vision", "car", "Car detected", 1.7, "left", 0.68)
    assert e.confidence == 1.0 and e.direction_confidence == 0.68
    assert e.model_dump()["direction"] == "left"

def test_unknown_direction_zeroes_direction_confidence():
    e = make_event("audio", "horn", "Vehicle horn", 0.8, "sideways", 0.9)
    assert e.direction == "unknown" and e.direction_confidence == 0.0

def test_speech_event_shape():
    e = make_event("speech", "speech", "Person speaking", 0.91, speech_text="Your bus is here")
    assert e.speech_text == "Your bus is here" and e.source == "speech"

# ---------- direction ----------
def test_bbox_direction_coarse_only():
    assert direction_from_bbox(0, 100, 1000)[0] == "left"
    assert direction_from_bbox(800, 950, 1000)[0] == "right"
    assert direction_from_bbox(450, 550, 1000)[0] == "front"
    assert direction_from_bbox(0, 10, 0) == ("unknown", 0.0)

def test_stereo_direction_and_mono_unknown():
    loud, quiet = np.ones(1000) * 0.5, np.ones(1000) * 0.05
    assert direction_from_stereo(loud, quiet)[0] == "left"
    assert direction_from_stereo(quiet, loud)[0] == "right"
    assert direction_from_stereo(loud, loud) == ("unknown", 0.0)

# ---------- YOLO event mapping (no model needed) ----------
def test_yolo_filters_unsupported_classes_and_picks_largest():
    d = YoloDetector()
    boxes = [("car", 0.9, 0, 0, 200, 200), ("car", 0.6, 0, 0, 50, 50),
             ("giraffe", 0.99, 0, 0, 10, 10), ("cell phone", 0.7, 800, 0, 900, 100)]
    ev = d.events_from_boxes(boxes, 1000, 1000)
    names = sorted(e.event for e in ev)
    assert names == ["car", "phone"]
    car = next(e for e in ev if e.event == "car")
    assert car.confidence == 0.9 and car.direction == "left"

def test_yolo_not_ready_returns_empty():
    assert YoloDetector().detect(b"junk") == []

# ---------- YAMNet mapping ----------
def test_yamnet_thresholds_and_supported_only():
    names = ["Speech", "Vehicle horn, car horn, honking", "Siren", "Dog", "Music"]
    scores = np.array([0.99, 0.6, 0.1, 0.44, 0.9])
    ev = YamnetClassifier.events_from_scores(scores, names, ("left", 0.5))
    assert [e.event for e in ev] == ["horn"]            # siren/dog below threshold, speech/music unsupported
    assert ev[0].direction == "left"

def test_yamnet_label_map_targets():
    assert {v[0] for v in LABEL_MAP.values()} >= {"horn", "siren", "alarm", "doorbell", "knock", "dog bark"}

# ---------- VAD / speech gating ----------
def tone(sec, amp): return (amp * np.sin(2*np.pi*220*np.arange(int(sec*SAMPLE_RATE))/SAMPLE_RATE)).astype(np.float32)

def test_vad_gates_silence():
    assert not is_speech(np.zeros(SAMPLE_RATE, np.float32))
    assert is_speech(tone(1, 0.3))

def test_segmenter_emits_after_trailing_silence():
    seg, out = SpeechSegmenter(), []
    for _ in range(4): out.append(seg.push(tone(0.25, 0.3)))
    for _ in range(4): out.append(seg.push(np.zeros(4000, np.float32)))
    got = [o for o in out if o is not None]
    assert len(got) == 1 and got[0].size >= SAMPLE_RATE

# ---------- pipeline with injected stand-ins (TEST ONLY; never used at runtime) ----------
class StubWhisper:
    ready = True
    def transcribe(self, pcm): return make_event("speech", "speech", "Person speaking", 0.9, speech_text="Your bus is here")
class StubYamnet:
    ready = True
    def classify(self, w, d=("unknown", 0.0)): return [make_event("audio", "horn", "Vehicle horn", 0.8)]

def test_pipeline_windows_audio_and_gates_whisper():
    m = Models(); m.yamnet, m.whisper = StubYamnet(), StubWhisper()
    s = Session(m)
    loud = (tone(2.0, 0.3) * 32767).astype("<i2").tobytes()
    ev = s.process_audio(loud)
    kinds = {e.source for e in ev}
    assert "audio" in kinds                        # windows were classified
    quiet = np.zeros(int(1.5*SAMPLE_RATE), "<i2").tobytes()
    ev2 = s.process_audio(quiet)                   # trailing silence closes the speech segment
    assert any(e.source == "speech" for e in ev + ev2)

def test_pcm_conversion():
    assert pcm16_to_float(b"\x00\x40").tolist() == [0.5]

# ---------- API ----------
client = TestClient(main.app)

def test_health_reports_model_status_without_crashing():
    r = client.get("/api/health").json()
    assert r["status"] == "ok" and set(r["models"]) == {"yolo", "yamnet", "whisper"}

def test_session_and_events_endpoints():
    sid = client.post("/api/session/start", json={"profile": "deaf"}).json()["session_id"]
    ev = make_event("audio", "alarm", "Alarm", 0.9).model_dump()
    assert client.post("/api/events", json=[ev]).json()["stored"] == 1
    assert client.get("/api/events").json()[0]["event"] == "alarm"
    assert client.post(f"/api/session/stop?session_id={sid}").json()["stopped"]

def test_websocket_ready_and_ping_and_bad_frame():
    with client.websocket_connect("/ws/awareness") as ws:
        assert ws.receive_json()["type"] == "ready"
        ws.send_text(json.dumps({"type": "frame", "data": base64.b64encode(b"not a jpeg").decode()}))
        ws.send_text(json.dumps({"type": "ping"}))
        assert ws.receive_json()["type"] == "pong"   # server survived a corrupt frame
