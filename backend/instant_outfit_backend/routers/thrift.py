"""Thrift Marketplace endpoints.

Serves the home-screen Thrift Marketplace section:

    GET /api/v1/thrift/nearby                  stores near a coordinate
    GET /api/v1/thrift/stores/{store_id}/items one store's catalogue

Distance strategy
-----------------
This database has no PostGIS extension, so proximity is resolved in two
stages rather than with a geography type:

1.  A bounding-box filter runs in SQL. It is a plain range scan over the
    ``(latitude, longitude)`` index, so the database never reads the whole
    table — this is the step that keeps the query fast as the store count
    grows.
2.  Exact great-circle distance is then computed in Python over that small
    candidate set, which removes the box's corners (a box circumscribes the
    circle, so its corners are further away than ``radius_km``).

Doing only step 1 would return stores up to ~41% beyond the requested radius
at the corners; doing only step 2 would force a full table scan.
"""

import math
from typing import Dict, List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from models import ThriftItem, ThriftListing, ThriftStore
from schemas import (
    ThriftItemOut,
    ThriftListingCreate,
    ThriftListingOut,
    ThriftStoreOut,
)

router = APIRouter(prefix="/api/v1/thrift", tags=["Thrift Marketplace"])

# Mean Earth radius (km), IUGG. Used by the haversine below.
EARTH_RADIUS_KM = 6371.0088

# Length of one degree of latitude in km. Constant everywhere; longitude is
# not, which is why the bounding box divides by cos(latitude).
KM_PER_DEGREE_LAT = 110.574


def haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Great-circle distance between two points in kilometres."""
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    d_phi = phi2 - phi1
    d_lambda = math.radians(lng2 - lng1)

    a = (
        math.sin(d_phi / 2) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(d_lambda / 2) ** 2
    )
    return 2 * EARTH_RADIUS_KM * math.asin(math.sqrt(a))


def bounding_box(lat: float, lng: float, radius_km: float):
    """Lat/lng box that fully contains the search circle.

    The longitude delta widens as latitude increases because meridians
    converge at the poles. Latitude is clamped to ±89.9° before taking the
    cosine so a near-polar request cannot divide by zero.
    """
    lat_delta = radius_km / KM_PER_DEGREE_LAT

    safe_lat = max(min(lat, 89.9), -89.9)
    km_per_degree_lng = KM_PER_DEGREE_LAT * math.cos(math.radians(safe_lat))
    lng_delta = radius_km / max(km_per_degree_lng, 0.0001)

    return (
        lat - lat_delta,
        lat + lat_delta,
        lng - lng_delta,
        lng + lng_delta,
    )


@router.get("/nearby", response_model=List[ThriftStoreOut])
async def get_nearby_stores(
    lat: float = Query(..., ge=-90, le=90, description="Caller latitude"),
    lng: float = Query(..., ge=-180, le=180, description="Caller longitude"),
    radius_km: float = Query(10.0, gt=0, le=100, description="Search radius"),
    limit: int = Query(10, gt=0, le=50, description="Max stores returned"),
    preview_limit: int = Query(
        4, ge=0, le=10, description="Preview items per store"
    ),
    db: AsyncSession = Depends(get_db),
):
    """Active stores within ``radius_km``, nearest first.

    Each store carries a short ``preview_items`` list so the client can render
    a rail without issuing a follow-up request per store.
    """
    min_lat, max_lat, min_lng, max_lng = bounding_box(lat, lng, radius_km)

    # Stage 1 — index-backed bounding box.
    result = await db.execute(
        select(ThriftStore).where(
            ThriftStore.is_active.is_(True),
            ThriftStore.latitude.between(min_lat, max_lat),
            ThriftStore.longitude.between(min_lng, max_lng),
        )
    )
    candidates = result.scalars().all()

    # Stage 2 — exact distance, trimming the box corners.
    within_radius = []
    for store in candidates:
        distance = haversine_km(lat, lng, store.latitude, store.longitude)
        if distance <= radius_km:
            within_radius.append((distance, store))

    within_radius.sort(key=lambda pair: pair[0])
    nearest = within_radius[:limit]

    if not nearest:
        return []

    # One query for every store's preview items, grouped in memory — avoids
    # the N+1 that a per-store fetch would cause.
    previews: Dict[UUID, List[ThriftItem]] = {}
    if preview_limit > 0:
        store_ids = [store.id for _, store in nearest]
        item_result = await db.execute(
            select(ThriftItem).where(
                ThriftItem.store_id.in_(store_ids),
                ThriftItem.is_available.is_(True),
            )
        )
        for item in item_result.scalars().all():
            bucket = previews.setdefault(item.store_id, [])
            if len(bucket) < preview_limit:
                bucket.append(item)

    return [
        ThriftStoreOut(
            id=store.id,
            name=store.name,
            area=store.area,
            image_url=store.image_url,
            latitude=store.latitude,
            longitude=store.longitude,
            distance_km=round(distance, 2),
            rating=store.rating or 0.0,
            item_count=store.item_count or 0,
            is_verified=bool(store.is_verified),
            preview_items=[
                ThriftItemOut.model_validate(item)
                for item in previews.get(store.id, [])
            ],
        )
        for distance, store in nearest
    ]


@router.get("/stores/{store_id}/items", response_model=List[ThriftItemOut])
async def get_store_items(
    store_id: UUID,
    category: Optional[str] = Query(None, description="Filter by category"),
    limit: int = Query(50, gt=0, le=200),
    db: AsyncSession = Depends(get_db),
):
    """Available items for one store.

    404s on an unknown store so the client can tell "this store has no stock"
    apart from "this store does not exist" — an empty list would conflate them.
    """
    store = await db.get(ThriftStore, store_id)
    if store is None or not store.is_active:
        raise HTTPException(status_code=404, detail="Thrift store not found")

    query = select(ThriftItem).where(
        ThriftItem.store_id == store_id,
        ThriftItem.is_available.is_(True),
    )
    if category:
        query = query.where(ThriftItem.category == category)

    result = await db.execute(query.limit(limit))
    return result.scalars().all()


# ── Seller listings ──────────────────────────────────────────────────────────


@router.post(
    "/listings",
    response_model=ThriftListingOut,
    status_code=status.HTTP_201_CREATED,
)
async def create_listing(
    payload: ThriftListingCreate,
    db: AsyncSession = Depends(get_db),
):
    """Submit a piece for sale.

    The listing is persisted as `pending` — it does not appear to buyers until
    moderation approves it. `status` is set here rather than read from the
    request so a client cannot self-publish.
    """
    listing = ThriftListing(
        seller_id=payload.seller_id,
        seller_name=payload.seller_name,
        title=payload.title,
        brand=payload.brand,
        category=payload.category,
        description=payload.description,
        size=payload.size,
        condition=payload.condition,
        price_in_paise=payload.price_in_paise,
        original_price_in_paise=payload.original_price_in_paise,
        image_urls=payload.image_urls,
        status="pending",
    )

    db.add(listing)
    await db.commit()
    await db.refresh(listing)
    return listing


@router.get("/listings", response_model=List[ThriftListingOut])
async def get_seller_listings(
    seller_id: str = Query(..., min_length=1, description="Firebase UID"),
    listing_status: Optional[str] = Query(
        None,
        alias="status",
        description="Filter by pending | live | sold | rejected",
    ),
    limit: int = Query(50, gt=0, le=200),
    db: AsyncSession = Depends(get_db),
):
    """A seller's own listings, newest first — backs the "My Listings" view."""
    query = select(ThriftListing).where(ThriftListing.seller_id == seller_id)
    if listing_status:
        query = query.where(ThriftListing.status == listing_status)

    query = query.order_by(ThriftListing.created_at.desc()).limit(limit)
    result = await db.execute(query)
    return result.scalars().all()


@router.delete("/listings/{listing_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_listing(
    listing_id: UUID,
    seller_id: str = Query(..., min_length=1),
    db: AsyncSession = Depends(get_db),
):
    """Withdraw a listing.

    Ownership is checked before deleting — without it, any caller who guessed
    a UUID could remove another seller's listing.
    """
    listing = await db.get(ThriftListing, listing_id)
    if listing is None:
        raise HTTPException(status_code=404, detail="Listing not found")
    if listing.seller_id != seller_id:
        raise HTTPException(
            status_code=403,
            detail="This listing belongs to another seller",
        )

    await db.delete(listing)
    await db.commit()
