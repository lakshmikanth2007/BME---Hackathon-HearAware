# HearAware - See with sound. Hear with light.

Flutter app + FastAPI backend. Camera -> OpenCV -> YOLO, microphone -> YAMNet + Whisper, then
**sensor fusion -> relevance engine -> profile** -> TTS (Blind) or a large visual alert (Deaf).

```
backend/   FastAPI, YOLO, YAMNet, Whisper, WebSocket /ws/awareness   (pytest: 16 tests)
mobile/    Flutter app (Riverpod)                                    (flutter test)
MODELS.md  model formats, supported classes, licences, honest limits
DEMO_CHECKLIST.md
```

## 1. Backend
```bash
cd backend
python -m venv .venv && source .venv/bin/activate      # Windows: .venv\Scripts\activate
pip install -r requirements.txt
python scripts/check_env.py                            # Phase 0 environment check (also downloads/loads models)
uvicorn app.main:app --host 0.0.0.0 --port 8000
pytest -q
```
Models load in the background; `/api/health` reports each one. If a model fails to load the server stays up and the
app tells the user which part is unavailable.

## 2. Mobile
```bash
cd mobile
flutter create --org com.hearaware --platforms android .   # generates android/ (keeps lib/ and pubspec.yaml)
python tools/patch_android.py                              # permissions, cleartext ws://, minSdk 24
flutter pub get
flutter test
flutter run
```
- Emulator reaches your laptop at `10.0.2.2:8000` (default). On a real phone open **Settings** and enter `LAN-IP:8000`.
- Firebase (optional): `flutterfire configure`. Without it the app runs local-only (guest); sign-in shows a clear message.
- Camera frames use `ImageFormatGroup.jpeg` (CameraX). If a device rejects it, Real Mode reports "Camera unavailable".

## Architecture in one screen
- **Perception (backend):** frames (5 FPS, newest-frame-wins) -> YOLO; PCM 16 kHz -> YAMNet windows + energy VAD -> Whisper. All emit the same normalized event JSON.
- **Fusion (`mobile/lib/fusion`):** vehicle sighting + horn/siren within 2.5 s -> one "vehicle horn" event. Sightings/horns wait 350 ms for a partner.
- **Relevance (`mobile/lib/relevance`):** HIGH/MEDIUM/LOW, confidence thresholds, per-event cooldown, duplicate suppression, rate limit, coverage by a fresh alert, profile filtering (Deaf users are not told what they can see).
- **Demo Mode** injects scripted normalized events at the top of that same pipeline. Same fusion, same relevance, same TTS/visual output.
- **Privacy:** sensors run only while Awareness Mode is on (Pause stops them); silence is not uploaded; frames/audio are processed in memory; only text events are stored.
