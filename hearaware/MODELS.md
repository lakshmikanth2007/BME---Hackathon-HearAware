# AI model documentation (spec section 28)

| | YOLO | YAMNet | Whisper |
|---|---|---|---|
| Purpose | Visual objects | Environmental sounds | Speech-to-text |
| Model | `yolov8n.pt` (Ultralytics; any YOLOv8/11 `.pt` via `YOLO_MODEL`) | `tfhub.dev/google/yamnet/1` | `faster-whisper` `tiny.en` (`WHISPER_MODEL` to change) |
| Format | PyTorch weights | TF SavedModel (TF Hub) | CTranslate2 int8 |
| Input | BGR frame (JPEG decoded with OpenCV), 416 px | mono float32, 16 kHz, 0.975 s windows | mono float32, 16 kHz, VAD-gated segments (0.6-8 s) |
| Output | boxes, class, score | 521 AudioSet scores | text + segment log-prob |
| Supported classes | **COCO 80 only.** Reported subset: person, car, bicycle, motorcycle, bus, truck, cell phone, laptop, chair, bottle, traffic light, stop sign, dog | AudioSet ontology. Mapped: vehicle horn, train/air horn, siren (incl. ambulance/police/fire), smoke/fire alarm, car alarm, alarm, doorbell, knock, dog/bark | English speech |
| Environment | Backend (CPU ok, GPU faster) | Backend (CPU) | Backend (CPU, int8) |
| Licence | **AGPL-3.0** (Ultralytics) - fine for a hackathon; publishing the code means the project must comply, or swap to a permissive detector | Apache-2.0 | MIT (Whisper); faster-whisper MIT |
| Device compat | Any machine running the backend; phone only streams | same | same |

## Honest limits
- YOLO cannot see traffic-light *state*, sounds, or anything outside COCO. We never claim otherwise.
- YAMNet scores are per-class sigmoids, not calibrated probabilities. Thresholds live in `backend/app/ai/yamnet.py` (`LABEL_MAP`).
- Speech is **not** taken from YAMNet; Whisper only transcribes.
- **Direction:** vision gives coarse left/front/right from the box position. A single phone mic gives **no** direction, so audio direction is `unknown` unless a 2-channel stereo stream is sent (interaural level difference, low confidence). Nothing "behind" is ever claimed from a forward camera. Event confidence and direction confidence are separate fields.
- "Approaching" = the same vehicle class's box area grew >30% over ~1-2.5 s. It is a heuristic hint, not distance estimation.
