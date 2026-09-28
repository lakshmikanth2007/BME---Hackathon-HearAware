"""Vision: OpenCV decode + YOLO detection -> normalized vision events.

Supported classes are exactly those of the loaded model (COCO for yolov8n / yolo11n).
Only the subset in RELEVANT_CLASSES is reported; nothing beyond the model's classes is claimed.
"""
from __future__ import annotations

import logging
import os
from collections import defaultdict, deque
from typing import Optional

import cv2
import numpy as np

from ..schemas import AwarenessEvent, make_event, now

log = logging.getLogger("hearaware.yolo")

RELEVANT_CLASSES = {
    "person", "car", "bicycle", "motorcycle", "bus", "truck",
    "cell phone", "laptop", "chair", "bottle", "traffic light", "stop sign", "dog",
}
VEHICLES = {"car", "bicycle", "motorcycle", "bus", "truck"}
LABEL_NAMES = {"cell phone": "phone"}


def direction_from_bbox(x1: float, x2: float, width: int) -> tuple[str, float]:
    """Coarse direction from the horizontal box centre (world-facing camera).
    Never returns 'behind': a single forward camera cannot see behind the user."""
    if width <= 0:
        return "unknown", 0.0
    cx = ((x1 + x2) / 2) / width
    if cx < 0.33:
        return "left", min(1.0, 0.6 + (0.33 - cx))
    if cx > 0.67:
        return "right", min(1.0, 0.6 + (cx - 0.67))
    return "front", min(1.0, 0.6 + (0.17 - abs(cx - 0.5)))


class YoloDetector:
    def __init__(self, model_path: Optional[str] = None, conf: float = 0.45, imgsz: int = 416):
        self.model_path = model_path or os.getenv("YOLO_MODEL", "yolov8n.pt")
        self.conf, self.imgsz = conf, imgsz
        self.model = None
        self.names: dict = {}
        self.error: Optional[str] = None
        self._area_hist: dict[str, deque] = defaultdict(lambda: deque(maxlen=12))

    def load(self) -> bool:
        try:
            from ultralytics import YOLO  # heavy import kept lazy
            self.model = YOLO(self.model_path)
            self.names = self.model.names
            log.info("YOLO loaded: %s (%d classes)", self.model_path, len(self.names))
            return True
        except Exception as e:  # a model loading failure must not crash the app
            self.error = f"YOLO unavailable: {e}"
            log.error(self.error)
            return False

    @property
    def ready(self) -> bool:
        return self.model is not None

    @staticmethod
    def decode(jpeg: bytes) -> Optional[np.ndarray]:
        return cv2.imdecode(np.frombuffer(jpeg, dtype=np.uint8), cv2.IMREAD_COLOR)

    def detect(self, jpeg: bytes) -> list[AwarenessEvent]:
        if not self.ready:
            return []
        img = self.decode(jpeg)
        if img is None:
            return []
        h, w = img.shape[:2]
        res = self.model.predict(img, conf=self.conf, imgsz=self.imgsz, verbose=False)[0]
        boxes = [(self.names[int(b.cls)], float(b.conf), *[float(v) for v in b.xyxy[0]]) for b in res.boxes]
        return self.events_from_boxes(boxes, w, h)

    def events_from_boxes(self, boxes, w: int, h: int) -> list[AwarenessEvent]:
        """boxes: iterable of (class_name, conf, x1, y1, x2, y2). Split out so it is unit-testable."""
        best: dict[str, tuple] = {}
        for name, conf, x1, y1, x2, y2 in boxes:
            if name not in RELEVANT_CLASSES:
                continue
            area = max(0.0, (x2 - x1) * (y2 - y1)) / max(1, w * h)
            if name not in best or area > best[name][4]:
                best[name] = (name, conf, x1, x2, area)
        t, events = now(), []
        for name, conf, x1, x2, area in best.values():
            approaching = False
            if name in VEHICLES:
                hist = self._area_hist[name]
                old = [a for ts, a in hist if 0.6 <= t - ts <= 2.5]
                if old and area > 0.03 and area / max(old[0], 1e-6) > 1.3:
                    approaching = True
                hist.append((t, area))
            d, dc = direction_from_bbox(x1, x2, w)
            label = LABEL_NAMES.get(name, name)
            events.append(make_event("vision", label, f"{label.capitalize()} detected", conf, d, dc,
                                     approaching=approaching))
        return events
