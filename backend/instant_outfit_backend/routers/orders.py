from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from database import get_db
from models import Order
from schemas import OrderCreate, OrderOut
from services.inventory import check_availability

router = APIRouter(prefix="/api/v1/orders", tags=["Orders"])

@router.post("", response_model=OrderOut)
async def place_order(order_in: OrderCreate, db: AsyncSession = Depends(get_db)):
    # Check inventory first
    avail = await check_availability(
        str(order_in.outfit_id),
        order_in.size,
        str(order_in.dark_store_id)
    )
    if not avail["available"]:
        raise HTTPException(status_code=409, detail="Item not available in selected size")

    order = Order(**order_in.model_dump())
    db.add(order)
    await db.commit()
    await db.refresh(order)
    return order