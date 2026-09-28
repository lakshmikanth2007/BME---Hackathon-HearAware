"""Per-session perception pipeline: frames -> YOLO, audio -> YAMNet + VAD -> Whisper.

Privacy: raw frames/audio are processed in memory and discarded. Only structured events leave this module.
"""
from __future__ import annotations

import base64
import binascii
import logging
import uuid
from dataclasses import dataclass, field
from typing import Optional

import numpy as np

from .ai.vad import SpeechSegmenter
from .ai.whisper_svc import WhisperTranscriber
from .ai.yamnet import WINDOW_SAMPLES, YamnetClassifier, direction_from_stereo
from .ai.yolo import YoloDetector
from .schemas import AwarenessEvent

log = logging.getLogger("hearaware.pipeline")


@dataclass
class Models:
    yolo: YoloDetector = field(default_factory=YoloDetector)
    yamnet: YamnetClassifier = field(default_factory=YamnetClassifier)
    whisper: WhisperTranscriber = field(default_factory=WhisperTranscriber)

    def load_all(self) -> None:
        for m in (self.yolo, self.yamnet, self.whisper):
            m.load()

    def status(self) -> dict:
        def s(m):
            return "ready" if m.ready else (m.error or "not loaded")
        return {"yolo": s(self.yolo), "yamnet": s(self.yamnet), "whisper": s(self.whisper)}


def pcm16_to_float(raw: bytes) -> np.ndarray:
    n = len(raw) // 2
    if n == 0:
        return np.zeros(0, dtype=np.float32)
    return np.frombuffer(raw[: n * 2], dtype="<i2").astype(np.float32) / 32768.0


def b64(data: str) -> Optional[bytes]:
    try:
        return base64.b64decode(data, validate=False)
    except (binascii.Error, ValueError):
        return None


class Session:
    SEG_BLOCK = 4000  # 0.25 s blocks fed to the VAD segmenter

    def __init__(self, models: Models, session_id: Optional[str] = None):
        self.id = session_id or uuid.uuid4().hex[:10]
        self.models = models
        self._yam_buf = np.zeros(0, dtype=np.float32)
        self._yam_dir_l: list[np.ndarray] = []
        self._yam_dir_r: list[np.ndarray] = []
        self._seg_buf = np.zeros(0, dtype=np.float32)
        self._segmenter = SpeechSegmenter()

    # ---- vision -------------------------------------------------------
    def process_frame(self, jpeg: bytes) -> list[AwarenessEvent]:
        try:
            return self.models.yolo.detect(jpeg)
        except Exception as e:
            log.warning("frame failed: %s", e)
            return []

    # ---- audio --------------------------------------------------------
    def process_audio(self, raw_pcm16: bytes, channels: int = 1) -> list[AwarenessEvent]:
        """raw_pcm16: little-endian int16, 16 kHz, interleaved if channels == 2."""
        x = pcm16_to_float(raw_pcm16)
        if x.size == 0:
            return []
        left = right = None
        if channels == 2 and x.size >= 2:
            x = x[: (x.size // 2) * 2].reshape(-1, 2)
            left, right = x[:, 0], x[:, 1]
            mono = x.mean(axis=1)
        else:
            mono = x
        events: list[AwarenessEvent] = []

        # YAMNet: environmental sounds, fixed 0.975 s windows
        self._yam_buf = np.concatenate([self._yam_buf, mono])
        if left is not None:
            self._yam_dir_l.append(left)
            self._yam_dir_r.append(right)
        while self._yam_buf.size >= WINDOW_SAMPLES:
            win, self._yam_buf = self._yam_buf[:WINDOW_SAMPLES], self._yam_buf[WINDOW_SAMPLES:]
            direction = ("unknown", 0.0)  # mono mic cannot give direction — we do not invent one
            if self._yam_dir_l:
                direction = direction_from_stereo(np.concatenate(self._yam_dir_l), np.concatenate(self._yam_dir_r))
                self._yam_dir_l, self._yam_dir_r = [], []
            try:
                events += self.models.yamnet.classify(win, direction)
            except Exception as e:
                log.warning("yamnet failed: %s", e)

        # Whisper: only VAD-gated speech segments
        self._seg_buf = np.concatenate([self._seg_buf, mono])
        while self._seg_buf.size >= self.SEG_BLOCK:
            block, self._seg_buf = self._seg_buf[: self.SEG_BLOCK], self._seg_buf[self.SEG_BLOCK:]
            seg = self._segmenter.push(block)
            if seg is not None:
                try:
                    ev = self.models.whisper.transcribe(seg)
                    if ev:
                        events.append(ev)
                except Exception as e:
                    log.warning("whisper failed: %s", e)
        return events
