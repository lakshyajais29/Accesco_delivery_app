from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from database import get_db
from models import Outfit
from schemas import OutfitOut
from typing import List, Optional

router = APIRouter(prefix="/api/v1/outfits", tags=["Outfits"])

@router.get("", response_model=List[OutfitOut])
async def get_outfits(
    occasion: Optional[str] = Query(None),
    size: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db)
):
    query = select(Outfit)
    if occasion:
        query = query.where(Outfit.category == occasion)
    result = await db.execute(query)
    outfits = result.scalars().all()

    if size:
        outfits = [o for o in outfits if size in (o.sizes or [])]

    return outfits