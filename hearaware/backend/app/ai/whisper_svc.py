"""Speech-to-text with Whisper (faster-whisper / CTranslate2 build of OpenAI Whisper).

Whisper is NOT an environmental sound classifier. It only turns speech segments into text.
"""
from __future__ import annotations

import logging
import os
from typing import Optional

import numpy as np

from ..schemas import AwarenessEvent, make_event

log = logging.getLogger("hearaware.whisper")


class WhisperTranscriber:
    def __init__(self, model_size: Optional[str] = None):
        self.model_size = model_size or os.getenv("WHISPER_MODEL", "tiny.en")
        self.model = None
        self.error: Optional[str] = None

    def load(self) -> bool:
        try:
            from faster_whisper import WhisperModel  # lazy: heavy
            self.model = WhisperModel(self.model_size, device="cpu", compute_type="int8")
            log.info("Whisper loaded: %s", self.model_size)
            return True
        except Exception as e:
            self.error = f"Whisper unavailable: {e}"
            log.error(self.error)
            return False

    @property
    def ready(self) -> bool:
        return self.model is not None

    def transcribe(self, pcm: np.ndarray) -> Optional[AwarenessEvent]:
        """pcm: mono float32 at 16 kHz (a VAD-gated speech segment)."""
        if not self.ready or pcm.size == 0:
            return None
        segments, _info = self.model.transcribe(
            pcm.astype(np.float32), language="en", beam_size=1,
            vad_filter=False, condition_on_previous_text=False)
        segs = list(segments)
        text = " ".join(s.text.strip() for s in segs).strip()
        if not text:
            return None
        # avg_logprob -> rough 0..1 score (a model score, not a guaranteed probability)
        avg = float(np.mean([s.avg_logprob for s in segs]))
        conf = float(max(0.0, min(1.0, np.exp(avg))))
        return speech_event(text, conf)


def speech_event(text: str, confidence: float) -> AwarenessEvent:
    return make_event("speech", "speech", "Person speaking", confidence, speech_text=text)
