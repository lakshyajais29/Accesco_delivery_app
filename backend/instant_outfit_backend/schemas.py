from pydantic import BaseModel
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