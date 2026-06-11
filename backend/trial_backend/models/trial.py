"""
models/trial.py
Pydantic schemas (request / response) + SQLAlchemy ORM model
"""
import enum
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field
from sqlalchemy import Column, String, Integer, Float, DateTime, Enum as SAEnum, JSON
from sqlalchemy.sql import func

from services.db import Base


# ═══════════════════════════════════════════════════════════════════════════════
# ENUMS
# ═══════════════════════════════════════════════════════════════════════════════
class TrialStatus(str, enum.Enum):
    active    = "active"
    completed = "completed"
    expired   = "expired"
    cancelled = "cancelled"


class OutfitDecision(str, enum.Enum):
    keep   = "keep"
    return_ = "return"


# ═══════════════════════════════════════════════════════════════════════════════
# ORM MODEL  (PostgreSQL table)
# ═══════════════════════════════════════════════════════════════════════════════
class TrialSessionDB(Base):
    """Permanent record written when a trial session is closed."""
    __tablename__ = "trial_sessions"

    id             = Column(Integer, primary_key=True, autoincrement=True)
    order_id       = Column(String(64),  nullable=False, index=True, unique=True)
    rider_id       = Column(String(64),  nullable=False)
    user_id        = Column(String(64),  nullable=False)
    status         = Column(SAEnum(TrialStatus), nullable=False, default=TrialStatus.active)
    start_time     = Column(DateTime(timezone=True), server_default=func.now())
    end_time       = Column(DateTime(timezone=True), nullable=True)
    kept_items     = Column(JSON, nullable=True)   # list of variant SKUs kept
    returned_items = Column(JSON, nullable=True)   # list of variant SKUs returned
    total_charged  = Column(Float, nullable=True)  # INR
    created_at     = Column(DateTime(timezone=True), server_default=func.now())
    updated_at     = Column(DateTime(timezone=True), onupdate=func.now())


# ═══════════════════════════════════════════════════════════════════════════════
# PYDANTIC — REQUEST SCHEMAS
# ═══════════════════════════════════════════════════════════════════════════════
class StartTrialRequest(BaseModel):
    rider_id: str = Field(..., description="Unique rider identifier")
    items: list[dict] = Field(
        ...,
        description="List of {variant_sku, product_name, unit_price_inr} for each trial item",
        example=[
            {"variant_sku": "PBL-AS-S-WHT", "product_name": "Silk Wrap Blouse", "unit_price_inr": 4200},
            {"variant_sku": "VKT-IC-M-IND", "product_name": "High-waist Palazzo",  "unit_price_inr": 3800},
        ]
    )


class KeepOutfitRequest(BaseModel):
    kept_skus: list[str] = Field(
        ...,
        description="variant_sku values the customer is keeping (empty list = returning all)",
        example=["PBL-AS-S-WHT", "VKT-IC-M-IND"]
    )
    payment_method_id: Optional[str] = Field(
        None,
        description="Razorpay / Stripe payment method ID (required when kept_skus is non-empty)"
    )


# ═══════════════════════════════════════════════════════════════════════════════
# PYDANTIC — RESPONSE SCHEMAS
# ═══════════════════════════════════════════════════════════════════════════════
class StartTrialResponse(BaseModel):
    session_started: bool
    order_id: str
    rider_id: str
    duration_seconds: int
    start_time: str
    message: str


class KeepOutfitResponse(BaseModel):
    success: bool
    order_id: str
    kept_count: int
    returned_count: int
    total_charged_inr: float
    payment_status: str   # "captured" | "zero_charge" | "failed"
    message: str