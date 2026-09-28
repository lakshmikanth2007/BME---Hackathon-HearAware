"""Lightweight energy-based Voice Activity Detection used to gate Whisper.

Whisper is expensive, so it only runs on segments that contain speech-like energy.
"""
from __future__ import annotations

import numpy as np

SAMPLE_RATE = 16000


def is_speech(pcm: np.ndarray, threshold: float = 0.015) -> bool:
    """pcm: float32 in [-1, 1]. True when enough 20 ms frames exceed the energy threshold."""
    if pcm.size < SAMPLE_RATE // 10:
        return False
    frame = SAMPLE_RATE // 50
    n = pcm.size // frame
    if n == 0:
        return False
    frames = pcm[: n * frame].astype(np.float32).reshape(n, frame)
    energy = np.sqrt(np.mean(np.square(frames), axis=1))
    return float(np.mean(energy > threshold)) > 0.15


class SpeechSegmenter:
    """Accumulates audio while speech is present; emits a segment after trailing silence."""

    def __init__(self, silence_s: float = 0.7, max_s: float = 8.0, min_s: float = 0.6,
                 threshold: float = 0.015):
        self.silence_s, self.max_s, self.min_s, self.threshold = silence_s, max_s, min_s, threshold
        self._buf: list[np.ndarray] = []
        self._silent = 0.0
        self._len = 0.0

    def push(self, chunk: np.ndarray):
        """Feed ~0.1-1 s chunks. Returns a float32 segment when one is complete, else None."""
        dur = chunk.size / SAMPLE_RATE
        if is_speech(chunk, self.threshold):
            self._buf.append(chunk)
            self._len += dur
            self._silent = 0.0
        elif self._buf:
            self._buf.append(chunk)
            self._len += dur
            self._silent += dur
        if self._buf and (self._silent >= self.silence_s or self._len >= self.max_s):
            seg = np.concatenate(self._buf)
            voiced = self._len - self._silent
            self._buf, self._silent, self._len = [], 0.0, 0.0
            return seg if voiced >= self.min_s else None
        return None
