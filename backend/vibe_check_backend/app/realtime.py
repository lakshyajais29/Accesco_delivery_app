"""Real-time fan-out for vibe check updates.

Two layers:
  1. ConnectionManager  – tracks live WebSocket connections per poll on THIS
                          process and writes messages to them.
  2. Redis pub/sub      – a single subscriber per process listens on the
                          `vibechan:*` pattern. When any worker publishes an
                          update it reaches every worker, which then forwards
                          it to its own local sockets. This is what lets the
                          feature scale past one uvicorn worker.
"""
from __future__ import annotations

import asyncio
import json
from collections import defaultdict
from typing import Any, Dict, Set

import redis.asyncio as redis
from fastapi import WebSocket

CHANNEL_PREFIX = "vibechan:"


def _channel(poll_id: str) -> str:
    return f"{CHANNEL_PREFIX}{poll_id}"


class ConnectionManager:
    def __init__(self) -> None:
        self._conns: Dict[str, Set[WebSocket]] = defaultdict(set)
        self._lock = asyncio.Lock()

    async def connect(self, poll_id: str, ws: WebSocket) -> None:
        await ws.accept()
        async with self._lock:
            self._conns[poll_id].add(ws)

    async def disconnect(self, poll_id: str, ws: WebSocket) -> None:
        async with self._lock:
            self._conns[poll_id].discard(ws)
            if not self._conns[poll_id]:
                self._conns.pop(poll_id, None)

    async def send_local(self, poll_id: str, message: Dict[str, Any]) -> None:
        """Send to sockets connected to THIS process only."""
        async with self._lock:
            targets = list(self._conns.get(poll_id, set()))
        dead: list[WebSocket] = []
        for ws in targets:
            try:
                await ws.send_json(message)
            except Exception:
                dead.append(ws)
        for ws in dead:
            await self.disconnect(poll_id, ws)


class RealtimeBus:
    """Publishes updates to Redis and forwards incoming ones to local sockets."""

    def __init__(self, client: redis.Redis, manager: ConnectionManager) -> None:
        self.r = client
        self.manager = manager
        self._task: asyncio.Task | None = None

    async def publish(self, poll_id: str, message: Dict[str, Any]) -> None:
        await self.r.publish(_channel(poll_id), json.dumps(message))

    async def start(self) -> None:
        self._task = asyncio.create_task(self._listen())

    async def stop(self) -> None:
        if self._task:
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass

    async def _listen(self) -> None:
        pubsub = self.r.pubsub()
        await pubsub.psubscribe(f"{CHANNEL_PREFIX}*")
        try:
            async for raw in pubsub.listen():
                if raw is None or raw.get("type") != "pmessage":
                    continue
                channel = raw["channel"]
                poll_id = channel[len(CHANNEL_PREFIX):]
                try:
                    message = json.loads(raw["data"])
                except (TypeError, ValueError):
                    continue
                await self.manager.send_local(poll_id, message)
        finally:
            await pubsub.punsubscribe(f"{CHANNEL_PREFIX}*")
            await pubsub.aclose()