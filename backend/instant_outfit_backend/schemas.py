from pydantic import BaseModel, Field, field_validator, model_validator
from typing import List, Optional
from uuid import UUID
from decimal import Decimal

class OutfitOut(BaseModel):
    id: UUID
    name: str
    category: str
    images: List[str]
    price: Decimal
    sizes: List[str]

    class Config:
        from_attributes = True

class OrderCreate(BaseModel):
    outfit_id: UUID
    size: str
    dark_store_id: UUID
    customer_lat: float
    customer_lng: float

class OrderOut(BaseModel):
    id: UUID
    outfit_id: UUID
    size: str
    status: str

    class Config:
        from_attributes = True

class TrackingOut(BaseModel):
    order_id: UUID
    status: str
    rider_lat: Optional[float]
    rider_lng: Optional[float]

# ── Thrift Marketplace ───────────────────────────────────────────────────────
# Field names are snake_case on the wire and are decoded verbatim by the
# Flutter models in lib/models/thrift_model.dart. Renaming anything here is a
# breaking change for the client.

class ThriftItemOut(BaseModel):
    id: UUID
    name: str
    brand: Optional[str] = None
    category: Optional[str] = None
    image_url: Optional[str] = None
    size: Optional[str] = None
    price_in_paise: int
    original_price_in_paise: Optional[int] = None
    condition: str
    co2_saved_kg: float = 0.0

    class Config:
        from_attributes = True


class ThriftStoreOut(BaseModel):
    id: UUID
    name: str
    area: Optional[str] = None
    image_url: Optional[str] = None
    latitude: float
    longitude: float

    # Computed per request from the caller's coordinates — not a column.
    distance_km: float

    rating: float = 0.0
    item_count: int = 0
    is_verified: bool = False
    preview_items: List[ThriftItemOut] = []

    class Config:
        from_attributes = True


# ── Thrift listings (seller submissions) ─────────────────────────────────────

class ThriftListingCreate(BaseModel):
    """Payload for POST /api/v1/thrift/listings.

    `status` is deliberately absent: a client cannot publish straight to live.
    Every submission enters moderation as 'pending'.
    """

    seller_id: str = Field(min_length=1, max_length=128)
    seller_name: Optional[str] = Field(default=None, max_length=120)

    title: str = Field(min_length=2, max_length=255)
    brand: Optional[str] = Field(default=None, max_length=120)
    category: Optional[str] = Field(default=None, max_length=60)
    description: Optional[str] = Field(default=None, max_length=2000)
    size: Optional[str] = Field(default="One Size", max_length=20)
    condition: str = Field(default="gentlyUsed")

    price_in_paise: int = Field(gt=0, le=100_000_000)
    original_price_in_paise: Optional[int] = Field(default=None, gt=0)

    image_urls: List[str] = Field(default_factory=list, max_length=6)

    @field_validator("condition")
    @classmethod
    def _known_condition(cls, value: str) -> str:
        allowed = {"likeNew", "gentlyUsed", "vintageFind"}
        if value not in allowed:
            raise ValueError(f"condition must be one of {sorted(allowed)}")
        return value

    @model_validator(mode="after")
    def _original_price_above_asking(self) -> "ThriftListingCreate":
        # A "was" price at or below the asking price would render as a zero or
        # negative discount on the product card.
        if (
            self.original_price_in_paise is not None
            and self.original_price_in_paise <= self.price_in_paise
        ):
            raise ValueError(
                "original_price_in_paise must be greater than price_in_paise"
            )
        return self


class ThriftListingOut(BaseModel):
    id: UUID
    seller_id: str
    seller_name: Optional[str] = None
    title: str
    brand: Optional[str] = None
    category: Optional[str] = None
    description: Optional[str] = None
    size: Optional[str] = None
    condition: str
    price_in_paise: int
    original_price_in_paise: Optional[int] = None
    image_urls: List[str] = []
    status: str
    rejection_reason: Optional[str] = None
    views: int = 0
    likes: int = 0

    class Config:
        from_attributes = True
