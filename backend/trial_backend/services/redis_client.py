"""
services/redis_client.py
Typed Redis helpers for Trial-at-Doorstep session state.

Key schema
──────────
  trial:{order_id}          →  JSON hash of TrialSessionData
  trial:{order_id}:lock     →  distributed lock (SETNX, 10 s TTL)
"""
import json
import os
import time
from typing import Optional

import redis.asyncio as aioredis

REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")
TRIAL_SESSION_TTL = int(os.getenv("TRIAL_SESSION_TTL_SECONDS", "3600"))

redis_client = aioredis.from_url(REDIS_URL, decode_responses=True)


# ── Key helpers ───────────────────────────────────────────────────────────────
def _session_key(order_id: str) -> str:
    return f"trial:{order_id}"


def _lock_key(order_id: str) -> str:
    return f"trial:{order_id}:lock"


# ── Session CRUD ──────────────────────────────────────────────────────────────
async def set_trial_session(order_id: str, data: dict) -> None:
    """Persist the full trial session dict to Redis with TTL."""
    await redis_client.setex(
        _session_key(order_id),
        TRIAL_SESSION_TTL,
        json.dumps(data),
    )


async def get_trial_session(order_id: str) -> Optional[dict]:
    """Return the session dict or None if expired / not found."""
    raw = await redis_client.get(_session_key(order_id))
    return json.loads(raw) if raw else None


async def delete_trial_session(order_id: str) -> None:
    await redis_client.delete(_session_key(order_id))


# ── Distributed lock (prevents double-payment race) ──────────────────────────
async def acquire_lock(order_id: str, ttl: int = 10) -> bool:
    """
    Returns True if lock was acquired (SETNX).
    Returns False if another request already holds it.
    """
    result = await redis_client.set(
        _lock_key(order_id), "1", nx=True, ex=ttl
    )
    return result is not None


async def release_lock(order_id: str) -> None:
    await redis_client.delete(_lock_key(order_id))