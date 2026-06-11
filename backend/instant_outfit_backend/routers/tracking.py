from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from database import get_db, AsyncSessionLocal
from models import Order
from schemas import TrackingOut
import asyncio, uuid

router = APIRouter(tags=["Tracking"])

@router.get("/api/v1/orders/{order_id}/track", response_model=TrackingOut)
async def get_tracking(order_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Order).where(Order.id == order_id))
    order = result.scalar_one_or_none()
    if not order:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Order not found")
    return TrackingOut(
        order_id=order.id,
        status=order.status,
        rider_lat=float(order.rider_lat) if order.rider_lat else None,
        rider_lng=float(order.rider_lng) if order.rider_lng else None,
    )

# WebSocket: wss://.../track/{order_id}
@router.websocket("/ws/track/{order_id}")
async def websocket_tracking(websocket: WebSocket, order_id: str):
    await websocket.accept()
    try:
        while True:
            async with AsyncSessionLocal() as db:
                result = await db.execute(
                    select(Order).where(Order.id == uuid.UUID(order_id))
                )
                order = result.scalar_one_or_none()
                if order:
                    await websocket.send_json({
                        "order_id": str(order.id),
                        "status": order.status,
                        "rider_lat": float(order.rider_lat) if order.rider_lat else None,
                        "rider_lng": float(order.rider_lng) if order.rider_lng else None,
                    })
            await asyncio.sleep(3)  # Push update every 3 seconds
    except WebSocketDisconnect:
        pass