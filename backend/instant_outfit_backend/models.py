from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    JSON,
    Numeric,
    String,
    func,
)
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

# ── Thrift Marketplace ───────────────────────────────────────────────────────
# Backs the home-screen Thrift Marketplace section: nearby stores plus the
# pre-loved pieces each one holds.

class ThriftStore(Base):
    __tablename__ = "thrift_stores"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(255), nullable=False)
    area = Column(String(120))                    # Neighbourhood, e.g. "Jubilee Hills"
    image_url = Column(String(512))

    # Stored as Float rather than Numeric: these are only ever used for
    # distance maths, never for money, so float precision is appropriate and
    # avoids Decimal/float coercion on every request.
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)

    rating = Column(Float, default=0.0)
    item_count = Column(Integer, default=0)
    is_verified = Column(Boolean, default=False)
    is_active = Column(Boolean, default=True)

    created_at = Column(DateTime, server_default=func.now())

    __table_args__ = (
        # The nearby query filters on a lat/lng bounding box before computing
        # exact distances, so a composite index over both columns is what
        # actually gets used.
        Index("ix_thrift_stores_lat_lng", "latitude", "longitude"),
    )


class ThriftItem(Base):
    __tablename__ = "thrift_items"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    store_id = Column(
        UUID(as_uuid=True),
        ForeignKey("thrift_stores.id", ondelete="CASCADE"),
        nullable=False,
    )

    name = Column(String(255), nullable=False)
    brand = Column(String(120))
    category = Column(String(60))                 # 'Dresses', 'Blazers', ...
    image_url = Column(String(512))
    size = Column(String(20), default="One Size")

    # Money is stored in paise as an integer. Floats cannot represent decimal
    # currency exactly, and the Flutter client already formats from paise.
    price_in_paise = Column(Integer, nullable=False)
    original_price_in_paise = Column(Integer)

    # 'likeNew' | 'gentlyUsed' | 'vintageFind' — matches the ThriftCondition
    # enum on the client and the grades the marketplace screen already shows.
    condition = Column(String(20), default="gentlyUsed")

    co2_saved_kg = Column(Float, default=0.0)
    is_available = Column(Boolean, default=True)

    created_at = Column(DateTime, server_default=func.now())

    __table_args__ = (
        Index("ix_thrift_items_store_available", "store_id", "is_available"),
    )


class ThriftListing(Base):
    """A seller-submitted listing, before and after it joins the catalogue.

    Kept separate from `thrift_items` deliberately: items are live inventory a
    buyer can purchase, whereas a listing is a *submission* that carries
    moderation state and seller ownership. Approving a listing is what creates
    the corresponding ThriftItem.
    """

    __tablename__ = "thrift_listings"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)

    # Firebase UID of the seller. A string rather than a FK because identity
    # lives in Firebase Auth, not in this database.
    seller_id = Column(String(128), nullable=False)
    seller_name = Column(String(120))

    title = Column(String(255), nullable=False)
    brand = Column(String(120))
    category = Column(String(60))
    description = Column(String(2000))
    size = Column(String(20), default="One Size")
    condition = Column(String(20), default="gentlyUsed")

    price_in_paise = Column(Integer, nullable=False)
    original_price_in_paise = Column(Integer)

    # Ordered image URLs; the first is the cover. JSON keeps the write simple
    # and the read atomic — there is no query that filters on an image.
    image_urls = Column(JSON, default=list)

    # 'pending' → 'live' → 'sold', or 'rejected'. New submissions always start
    # pending; the client cannot set this.
    status = Column(String(20), default="pending", nullable=False)
    rejection_reason = Column(String(500))

    views = Column(Integer, default=0)
    likes = Column(Integer, default=0)

    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    __table_args__ = (
        # "My Listings" reads by seller and orders by recency; this index
        # serves that exact query.
        Index("ix_thrift_listings_seller_created", "seller_id", "created_at"),
        Index("ix_thrift_listings_status", "status"),
    )
