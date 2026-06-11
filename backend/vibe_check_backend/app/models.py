"""Request/response models for the Vibe Check API.

These mirror the data the Flutter `VibeCheckScreen` actually uses:
a single product, YES/MAYBE/NO reactions keyed by voter, a creator,
a selected-friends list, stock, and a 24h expiry window.
"""
from __future__ import annotations

from enum import Enum
from typing import Dict, List, Optional

from pydantic import BaseModel, Field


class Reaction(str, Enum):
    YES = "YES"
    MAYBE = "MAYBE"
    NO = "NO"


class CreateVibeCheckRequest(BaseModel):
    # Sent by VibeCheckService.createVibeCheck on the Flutter side.
    product_id: str
    product_name: str
    product_category: str
    product_price: str
    product_image: str
    product_stock: int = 99
    creator_id: str
    creator_name: str = "Someone"
    selected_friend_ids: List[str] = Field(default_factory=list)


class CreateVibeCheckResponse(BaseModel):
    poll_id: str
    share_url: str


class ReactRequest(BaseModel):
    # voter_token identifies the reacting device/user. When the friend is a
    # logged-in app user this is their user id, so the creator's "who voted"
    # view can match reactions back to the selected friends.
    voter_token: str
    reaction: Reaction


class VoteTally(BaseModel):
    YES: int = 0
    MAYBE: int = 0
    NO: int = 0
    total: int = 0


class VibeCheck(BaseModel):
    id: str
    product_id: str
    product_name: str
    product_category: str
    product_price: str
    product_image: str
    product_stock: int
    creator_id: str
    creator_name: str
    selected_friend_ids: List[str]
    status: str
    created_at: str
    expires_at: str


class ResultsResponse(BaseModel):
    poll_id: str
    reactions: Dict[str, str]   # voter_token -> reaction
    tally: VoteTally


class StockResponse(BaseModel):
    product_id: str
    stock: int


class SetStockRequest(BaseModel):
    stock: int