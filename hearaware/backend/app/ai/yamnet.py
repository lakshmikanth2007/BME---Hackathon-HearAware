"""Environmental sound classification with YAMNet (AudioSet, 521 classes, 16 kHz mono, 0.975 s windows).

Only sounds YAMNet's ontology actually contains are mapped; everything else is ignored.
Speech is deliberately NOT reported here — Whisper owns speech content.
"""
from __future__ import annotations

import logging
from typing import Optional

import numpy as np

from ..schemas import AwarenessEvent, make_event

log = logging.getLogger("hearaware.yamnet")

WINDOW_SAMPLES = 15600  # 0.975 s @ 16 kHz

# AudioSet display name -> (normalized event, description, min score)
LABEL_MAP: dict[str, tuple[str, str, float]] = {
    "Vehicle horn, car horn, honking": ("horn", "Vehicle horn", 0.30),
    "Car alarm": ("alarm", "Alarm", 0.35),
    "Train horn": ("horn", "Train horn", 0.35),
    "Air horn, truck horn": ("horn", "Truck horn", 0.35),
    "Siren": ("siren", "Siren", 0.30),
    "Civil defense siren": ("siren", "Siren", 0.30),
    "Ambulance (siren)": ("siren", "Ambulance siren", 0.30),
    "Police car (siren)": ("siren", "Police siren", 0.30),
    "Fire engine, fire truck (siren)": ("siren", "Fire engine siren", 0.30),
    "Emergency vehicle": ("siren", "Emergency vehicle", 0.30),
    "Smoke detector, smoke alarm": ("alarm", "Smoke alarm", 0.30),
    "Fire alarm": ("alarm", "Fire alarm", 0.30),
    "Alarm": ("alarm", "Alarm", 0.40),
    "Doorbell": ("doorbell", "Doorbell", 0.40),
    "Ding-dong": ("doorbell", "Doorbell", 0.40),
    "Knock": ("knock", "Knocking", 0.40),
    "Dog": ("dog bark", "Dog barking", 0.45),
    "Bark": ("dog bark", "Dog barking", 0.45),
}


def direction_from_stereo(left: np.ndarray, right: np.ndarray) -> tuple[str, float]:
    """Interaural level difference. Only meaningful with a real 2-mic stereo capture.
    Mono input or a small difference -> 'unknown' (we never invent a direction)."""
    l = float(np.sqrt(np.mean(np.square(left)))) + 1e-9
    r = float(np.sqrt(np.mean(np.square(right)))) + 1e-9
    ratio = np.log(l / r)  # >0 => louder on the left
    if abs(ratio) < 0.25:
        return "unknown", 0.0
    return ("left" if ratio > 0 else "right"), float(min(0.6, 0.3 + abs(ratio) / 3))


class YamnetClassifier:
    def __init__(self):
        self.model = None
        self.class_names: list[str] = []
        self.error: Optional[str] = None

    def load(self) -> bool:
        try:
            import csv
            import tensorflow_hub as hub  # lazy: heavy
            self.model = hub.load("https://tfhub.dev/google/yamnet/1")
            path = self.model.class_map_path().numpy().decode("utf-8")
            with open(path, newline="") as f:
                self.class_names = [row["display_name"] for row in csv.DictReader(f)]
            log.info("YAMNet loaded (%d classes)", len(self.class_names))
            return True
        except Exception as e:
            self.error = f"YAMNet unavailable: {e}"
            log.error(self.error)
            return False

    @property
    def ready(self) -> bool:
        return self.model is not None

    def classify(self, pcm: np.ndarray, direction: tuple[str, float] = ("unknown", 0.0)) -> list[AwarenessEvent]:
        """pcm: mono float32 in [-1, 1] at 16 kHz."""
        if not self.ready or pcm.size < WINDOW_SAMPLES // 2:
            return []
        scores, _emb, _spec = self.model(pcm.astype(np.float32))
        return self.events_from_scores(scores.numpy().max(axis=0), self.class_names, direction)

    @staticmethod
    def events_from_scores(scores: np.ndarray, class_names: list[str],
                           direction: tuple[str, float] = ("unknown", 0.0)) -> list[AwarenessEvent]:
        """Testable core: map a 521-vector of scores to supported, thresholded events (best per event)."""
        best: dict[str, tuple[str, float]] = {}
        for idx, name in enumerate(class_names):
            m = LABEL_MAP.get(name)
            if not m or idx >= len(scores):
                continue
            ev, desc, min_score = m
            s = float(scores[idx])
            if s >= min_score and (ev not in best or s > best[ev][1]):
                best[ev] = (desc, s)
        return [make_event("audio", ev, desc, s, direction[0], direction[1]) for ev, (desc, s) in best.items()]
