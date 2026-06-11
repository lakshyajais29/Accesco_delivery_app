"""Redis-backed storage for vibe checks, reactions, and product stock.

Key layout
----------
  vibe:{poll_id}                -> JSON blob of the vibe check metadata
  vibe:{poll_id}:reactions      -> HASH voter_token -> reaction  (YES/MAYBE/NO)
  product:{product_id}:stock    -> integer stock count

Double-vote prevention uses HSETNX on the reactions hash, which is atomic:
the first reaction for a given voter_token writes, any later one is rejected.
"""
from __future__ import annotations

import json
import uuid
from datetime import datetime, timedelta, timezone

import redis.asyncio as redis

from .models import (
    CreateVibeCheckRequest,
    Reaction,
    ResultsResponse,
    VibeCheck,
    VoteTally,
)

# Vibe checks live for 24h (matches the Flutter `expiresAt` window).
VIBE_TTL_SECONDS = 24 * 60 * 60
DEFAULT_STOCK = 99


class AlreadyVotedError(Exception):
    """Raised when a voter_token tries to react more than once."""


class NotFoundError(Exception):
    """Raised when a poll is missing or has expired."""


class Store:
    def __init__(self, client: redis.Redis):
        self.r = client

    # ── keys ────────────────────────────────────────────────────────────────
    @staticmethod
    def _vibe_key(poll_id: str) -> str:
        return f"vibe:{poll_id}"

    @staticmethod
    def _reactions_key(poll_id: str) -> str:
        return f"vibe:{poll_id}:reactions"

    @staticmethod
    def _stock_key(product_id: str) -> str:
        return f"product:{product_id}:stock"

    # ── vibe checks ──────────────────────────────────────────────────────────
    async def create_vibe_check(self, req: CreateVibeCheckRequest) -> VibeCheck:
        poll_id = str(uuid.uuid4())
        now = datetime.now(timezone.utc)
        vibe = VibeCheck(
            id=poll_id,
            product_id=req.product_id,
            product_name=req.product_name,
            product_category=req.product_category,
            product_price=req.product_price,
            product_image=req.product_image,
            product_stock=req.product_stock,
            creator_id=req.creator_id,
            creator_name=req.creator_name,
            selected_friend_ids=req.selected_friend_ids,
            status="active",
            created_at=now.isoformat(),
            expires_at=(now + timedelta(seconds=VIBE_TTL_SECONDS)).isoformat(),
        )
        await self.r.set(
            self._vibe_key(poll_id), vibe.model_dump_json(), ex=VIBE_TTL_SECONDS
        )
        # Seed stock for this product if it has never been set.
        await self.r.set(
            self._stock_key(req.product_id), req.product_stock, nx=True
        )
        return vibe

    async def get_vibe_check(self, poll_id: str) -> VibeCheck:
        raw = await self.r.get(self._vibe_key(poll_id))
        if raw is None:
            raise NotFoundError(poll_id)
        return VibeCheck(**json.loads(raw))

    # ── reactions ─────────────────────────────────────────────────────────────
    async def add_reaction(
        self, poll_id: str, voter_token: str, reaction: Reaction
    ) -> None:
        # Confirm the poll still exists (also enforces expiry).
        if not await self.r.exists(self._vibe_key(poll_id)):
            raise NotFoundError(poll_id)

        key = self._reactions_key(poll_id)
        # HSETNX is atomic: returns 1 only if the field was absent.
        created = await self.r.hsetnx(key, voter_token, reaction.value)
        if not created:
            raise AlreadyVotedError(voter_token)
        # Keep the reactions hash on the same TTL as the vibe check.
        await self.r.expire(key, VIBE_TTL_SECONDS)

    async def get_reactions(self, poll_id: str) -> dict[str, str]:
        raw = await self.r.hgetall(self._reactions_key(poll_id))

        def _s(v):  # normalize bytes -> str (real client decodes; be defensive)
            return v.decode() if isinstance(v, (bytes, bytearray)) else v

        return {_s(k): _s(v) for k, v in raw.items()}

    async def get_results(self, poll_id: str) -> ResultsResponse:
        if not await self.r.exists(self._vibe_key(poll_id)):
            raise NotFoundError(poll_id)
        reactions = await self.get_reactions(poll_id)
        tally = VoteTally(
            YES=sum(1 for v in reactions.values() if v == "YES"),
            MAYBE=sum(1 for v in reactions.values() if v == "MAYBE"),
            NO=sum(1 for v in reactions.values() if v == "NO"),
            total=len(reactions),
        )
        return ResultsResponse(poll_id=poll_id, reactions=reactions, tally=tally)

    # ── stock ─────────────────────────────────────────────────────────────────
    async def get_stock(self, product_id: str) -> int:
        val = await self.r.get(self._stock_key(product_id))
        return int(val) if val is not None else DEFAULT_STOCK

    async def set_stock(self, product_id: str, stock: int) -> int:
        await self.r.set(self._stock_key(product_id), stock)
        return stock

    async def decrement_stock(self, product_id: str, by: int = 1) -> int:
        # DECRBY is atomic; floor at zero.
        new_val = await self.r.decrby(self._stock_key(product_id), by)
        if new_val < 0:
            await self.r.set(self._stock_key(product_id), 0)
            new_val = 0
        return int(new_val)