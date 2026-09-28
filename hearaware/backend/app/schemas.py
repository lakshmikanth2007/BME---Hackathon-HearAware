"""Normalized event format shared by every perception model (spec section 7)."""
from __future__ import annotations

import time
import uuid
from datetime import datetime, timezone
from typing import Literal, Optional

from pydantic import BaseModel, Field

Direction = Literal["left", "right", "front", "behind", "unknown"]
Source = Literal["vision", "audio", "speech", "fusion"]


class AwarenessEvent(BaseModel):
    id: str = Field(default_factory=lambda: uuid.uuid4().hex[:12])
    timestamp: str = Field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    source: Source
    event: str
    description: str
    confidence: float = Field(ge=0.0, le=1.0)  # EVENT confidence: a model score, not a guaranteed probability
    direction: Direction = "unknown"
    direction_confidence: float = Field(default=0.0, ge=0.0, le=1.0)  # deliberately separate
    speech_text: Optional[str] = None
    approaching: bool = False  # vision hint used by the relevance engine


def make_event(source: str, event: str, description: str, confidence: float,
               direction: str = "unknown", direction_confidence: float = 0.0,
               speech_text: Optional[str] = None, approaching: bool = False) -> AwarenessEvent:
    if direction not in ("left", "right", "front", "behind", "unknown"):
        direction = "unknown"
    if direction == "unknown":
        direction_confidence = 0.0
    clamp = lambda v: round(float(max(0.0, min(1.0, v))), 3)  # noqa: E731
    return AwarenessEvent(
        source=source, event=event, description=description,
        confidence=clamp(confidence), direction=direction,
        direction_confidence=clamp(direction_confidence),
        speech_text=speech_text, approaching=approaching,
    )


def now() -> float:
    return time.time()
