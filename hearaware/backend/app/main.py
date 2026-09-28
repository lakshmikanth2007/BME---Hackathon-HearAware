"""HearAware backend: AI inference + WebSocket event streaming.

Run:  uvicorn app.main:app --host 0.0.0.0 --port 8000
"""
from __future__ import annotations

import asyncio
import json
import logging
import os
import threading
from collections import deque
from contextlib import asynccontextmanager
from typing import Optional

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from pydantic import BaseModel

from .pipeline import Models, Session, b64
from .schemas import AwarenessEvent

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("hearaware")

models = Models()
sessions: dict[str, Session] = {}
history: deque[dict] = deque(maxlen=500)


@asynccontextmanager
async def lifespan(_app: FastAPI):
    # Load models in the background so the API (and /api/health) is reachable immediately.
    if os.getenv("HEARAWARE_SKIP_MODELS") != "1":
        threading.Thread(target=models.load_all, daemon=True).start()
    yield


app = FastAPI(title="HearAware API", version="1.0.0", lifespan=lifespan)


class StartBody(BaseModel):
    profile: str = "blind"  # blind | deaf


@app.get("/api/health")
def health():
    st = models.status()
    return {"status": "ok", "models": st, "all_ready": all(v == "ready" for v in st.values())}


@app.post("/api/session/start")
def session_start(body: StartBody):
    s = Session(models)
    sessions[s.id] = s
    return {"session_id": s.id, "profile": body.profile, "models": models.status()}


@app.post("/api/session/stop")
def session_stop(session_id: Optional[str] = None):
    sessions.pop(session_id or "", None)
    return {"stopped": True}


@app.post("/api/events")
def post_events(events: list[AwarenessEvent]):
    """Store structured events (text only — never raw media)."""
    history.extend(e.model_dump() for e in events)
    return {"stored": len(events)}


@app.get("/api/events")
def get_events(limit: int = 50):
    return list(history)[-max(1, min(limit, 500)):][::-1]


@app.websocket("/ws/awareness")
async def ws_awareness(ws: WebSocket, session_id: Optional[str] = None):
    await ws.accept()
    session = sessions.get(session_id or "") or Session(models, session_id)
    sessions[session.id] = session
    send_lock = asyncio.Lock()
    latest_frame: dict = {"data": None}
    frame_evt = asyncio.Event()
    audio_q: asyncio.Queue = asyncio.Queue(maxsize=40)

    async def send(obj: dict):
        async with send_lock:
            await ws.send_text(json.dumps(obj))

    async def emit(events: list[AwarenessEvent]):
        if events:
            history.extend(e.model_dump() for e in events)
            await send({"type": "events", "events": [e.model_dump() for e in events]})

    async def frame_worker():
        while True:  # only the newest frame is processed: stale frames are dropped, keeping latency low
            await frame_evt.wait()
            frame_evt.clear()
            jpeg, latest_frame["data"] = latest_frame["data"], None
            if jpeg:
                await emit(await asyncio.to_thread(session.process_frame, jpeg))

    async def audio_worker():
        while True:
            raw, ch = await audio_q.get()
            await emit(await asyncio.to_thread(session.process_audio, raw, ch))

    await send({"type": "ready", "session_id": session.id, "models": models.status()})
    workers = [asyncio.create_task(frame_worker()), asyncio.create_task(audio_worker())]
    try:
        while True:
            msg = json.loads(await ws.receive_text())
            t = msg.get("type")
            if t == "frame":
                raw = b64(msg.get("data", ""))
                if raw:
                    latest_frame["data"] = raw
                    frame_evt.set()
            elif t == "audio":
                raw = b64(msg.get("data", ""))
                if raw:
                    if audio_q.full():
                        audio_q.get_nowait()  # drop oldest under load
                    audio_q.put_nowait((raw, int(msg.get("channels", 1))))
            elif t == "status":
                await send({"type": "status", "models": models.status()})
            elif t == "ping":
                await send({"type": "pong"})
    except (WebSocketDisconnect, json.JSONDecodeError):
        pass
    except Exception as e:  # never crash the server on a bad client
        log.warning("ws error: %s", e)
    finally:
        for w in workers:
            w.cancel()
        sessions.pop(session.id, None)
