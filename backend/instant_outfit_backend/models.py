from sqlalchemy import Column, String, Numeric, Integer, DateTime, JSON, func
from sqlalchemy.dialects.postgresql import UUID
import uuid
from database import Base

class Outfit(Base):
    __tablename__ = "outfits"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(255), nullable=False)
    category = Column(String(50))  # 'date_night', 'office', 'party', 'casual'
    images = Column(JSON)          # list of image URLs
    price = Column(Numeric(10, 2))
    sizes = Column(JSON)           # ["S","M","L","XL"]
    created_at = Column(DateTime, server_default=func.now())


class DarkStoreInventory(Base):
    __tablename__ = "dark_store_inventory"

    dark_store_id = Column(UUID(as_uuid=True), primary_key=True)
    sku = Column(String(100), primary_key=True)
    size = Column(String(10), primary_key=True)
    quantity = Column(Integer)
    location_bin = Column(String(20))  # e.g. "A-12"
    last_updated = Column(DateTime, server_default=func.now(), onupdate=func.now())


class Order(Base):
    __tablename__ = "orders"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    outfit_id = Column(UUID(as_uuid=True), nullable=False)
    size = Column(String(10))
    dark_store_id = Column(UUID(as_uuid=True))
    status = Column(String(50), default="placed")  # placed, assembling, picked, delivered
    customer_lat = Column(Numeric(10, 6))
    customer_lng = Column(Numeric(10, 6))
    rider_lat = Column(Numeric(10, 6))
    rider_lng = Column(Numeric(10, 6))
    created_at = Column(DateTime, server_default=func.now())