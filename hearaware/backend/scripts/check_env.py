"""Phase 0 — environment verification. Run:  python scripts/check_env.py"""
import importlib, os, shutil, subprocess, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

def run(cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=60).stdout.strip().splitlines()[0]
    except Exception as e:
        return f"unavailable ({e.__class__.__name__})"

rows, ok = [], True
def check(name, good, detail=""):
    global ok
    ok &= bool(good)
    rows.append(("OK  " if good else "FAIL", name, detail))

check("Python >= 3.10", sys.version_info >= (3, 10), sys.version.split()[0])
for mod in ["fastapi", "uvicorn", "numpy", "cv2", "pydantic", "ultralytics", "tensorflow", "tensorflow_hub", "faster_whisper"]:
    try:
        m = importlib.import_module(mod); check(f"python pkg {mod}", True, getattr(m, "__version__", ""))
    except Exception as e:
        check(f"python pkg {mod}", False, "pip install -r requirements.txt")
check("flutter on PATH", shutil.which("flutter"), run(["flutter", "--version"]) if shutil.which("flutter") else "install Flutter SDK")
check("dart on PATH", shutil.which("dart"), "")
check("adb (Android SDK platform-tools)", shutil.which("adb"), "needed to run on a device")
try:
    from app.ai.yolo import YoloDetector
    y = YoloDetector(); check("YOLO weights load", y.load(), y.error or y.model_path)
except Exception as e:
    check("YOLO weights load", False, str(e))
try:
    from app.ai.yamnet import YamnetClassifier
    m = YamnetClassifier(); check("YAMNet load (needs internet once)", m.load(), m.error or "")
except Exception as e:
    check("YAMNet load", False, str(e))
try:
    from app.ai.whisper_svc import WhisperTranscriber
    w = WhisperTranscriber(); check("Whisper load (needs internet once)", w.load(), w.error or w.model_size)
except Exception as e:
    check("Whisper load", False, str(e))
for r in rows: print(f"[{r[0]}] {r[1]:42s} {r[2]}")
print("\nALL GOOD" if ok else "\nFix the FAIL items above before running Real Mode (Demo Mode works without models).")
sys.exit(0 if ok else 1)
