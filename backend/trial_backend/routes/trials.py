"""
routes/trials.py
FastAPI router — Trial at Doorstep endpoints

POST /api/v1/trials/{order_id}/start   → start_trial_session
POST /api/v1/trials/{order_id}/keep    → keep_outfit (CONFIRM & PAY)
GET  /api/v1/trials/{order_id}/status  → current session state (polling fallback)
POST /api/v1/trials/{order_id}/cancel  → cancel before rider arrives
"""
import os

import logging
from fastapi import APIRouter, Depends, HTTPException, Header, BackgroundTasks
from sqlalchemy.ext.asyncio import AsyncSession

from models.trial import (
    StartTrialRequest,
    StartTrialResponse,
    KeepOutfitRequest,
    KeepOutfitResponse,
)
from services.db import get_db
from services.redis_client import get_trial_session
from services.trial_service import (
    start_trial_session,
    keep_outfit,
    expire_trial,
)

router = APIRouter()
logger = logging.getLogger(__name__)


# ── Simple API-key auth (replace with JWT in production) ─────────────────────
async def verify_api_key(x_api_key: str = Header(..., alias="X-API-Key")):
    """
    Replace with proper JWT Bearer auth in production:
        Authorization: Bearer <firebase_id_token>
    Verify via firebase_admin.auth.verify_id_token(token)
    """
    expected = os.getenv("INTERNAL_API_KEY", "dev-key-change-me")
    if x_api_key != expected:
        raise HTTPException(status_code=401, detail="Invalid API key")
    return x_api_key


# ════════════════════════════════════════════════════════════════════════════
# POST /api/v1/trials/{order_id}/start
# ════════════════════════════════════════════════════════════════════════════
@router.post(
    "/{order_id}/start",
    response_model=StartTrialResponse,
    summary="Start a trial session when rider arrives",
)
async def start_trial(
    order_id:         str,
    body:             StartTrialRequest,
    background_tasks: BackgroundTasks,
    db:               AsyncSession = Depends(get_db),
    _:                str          = Depends(verify_api_key),
):
    """
    Called by the Flutter app the moment the rider arrives.
    - Creates a Redis session (TTL = 15 min)
    - Persists to PostgreSQL
    - Marks rider busy
    - Sends 'Try it on!' push notification

    The background task schedules an expiry job 15 minutes out.
    """
    try:
        result = await start_trial_session(
            order_id = order_id,
            rider_id = body.rider_id,
            items    = body.items,
            db       = db,
        )

        # Schedule expiry cleanup after 15 min (900 s)
        # In production: use Celery beat or APScheduler instead of BackgroundTasks
        # BackgroundTasks is fine for single-instance deployments
        import asyncio
        import os

        TRIAL_DURATION = int(os.getenv("TRIAL_DURATION_SECONDS", "900"))

        async def _scheduled_expire():
            await asyncio.sleep(TRIAL_DURATION + 5)  # +5s grace
            from services.db import AsyncSessionLocal
            async with AsyncSessionLocal() as expire_db:
                await expire_trial(order_id=order_id, db=expire_db)

        background_tasks.add_task(_scheduled_expire)

        return StartTrialResponse(**result)

    except Exception as exc:
        logger.exception("start_trial failed for order %s", order_id)
        raise HTTPException(status_code=500, detail=str(exc))


# ════════════════════════════════════════════════════════════════════════════
# POST /api/v1/trials/{order_id}/keep
# ════════════════════════════════════════════════════════════════════════════
@router.post(
    "/{order_id}/keep",
    response_model=KeepOutfitResponse,
    summary="Confirm kept items and process payment (CONFIRM & PAY)",
)
async def keep_outfit_endpoint(
    order_id: str,
    body:     KeepOutfitRequest,
    db:       AsyncSession = Depends(get_db),
    _:        str          = Depends(verify_api_key),
):
    """
    Called by Flutter's `_confirmAndPay()` after the customer decides.
    - Locks session (prevents double-payment)
    - Calculates total for kept SKUs only
    - Runs Razorpay capture
    - Updates PostgreSQL
    - Clears Redis session
    - Releases rider
    """
    try:
        result = await keep_outfit(
            order_id          = order_id,
            kept_skus         = body.kept_skus,
            payment_method_id = body.payment_method_id,
            db                = db,
        )
        return KeepOutfitResponse(**result)

    except ValueError as exc:
        # Business rule violations (expired session, missing payment method, etc.)
        raise HTTPException(status_code=422, detail=str(exc))

    except RuntimeError as exc:
        # Payment failures
        raise HTTPException(status_code=402, detail=str(exc))

    except Exception as exc:
        logger.exception("keep_outfit failed for order %s", order_id)
        raise HTTPException(status_code=500, detail=str(exc))


# ════════════════════════════════════════════════════════════════════════════
# GET /api/v1/trials/{order_id}/status
# ════════════════════════════════════════════════════════════════════════════
@router.get(
    "/{order_id}/status",
    summary="Poll current trial session state (fallback for missed push notifications)",
)
async def get_trial_status(
    order_id: str,
    _:        str = Depends(verify_api_key),
):
    """
    Returns live session state from Redis.
    Flutter polls this every 30 s as a fallback if the push notification is missed.
    """
    session = await get_trial_session(order_id)
    if not session:
        return {
            "order_id":  order_id,
            "status":    "not_found",
            "remaining": 0,
        }

    import time
    from datetime import datetime, timezone

    start_time = datetime.fromisoformat(session["start_time"])
    elapsed    = (datetime.now(timezone.utc) - start_time).total_seconds()
    remaining  = max(0, int(os.getenv("TRIAL_DURATION_SECONDS", "900")) - elapsed)

    return {
        "order_id":         order_id,
        "status":           session.get("status", "unknown"),
        "remaining_seconds": int(remaining),
        "rider_id":         session.get("rider_id"),
        "items_count":      len(session.get("items", [])),
    }


import os  # needed by get_trial_status (moved here for clarity)


# ════════════════════════════════════════════════════════════════════════════
# POST /api/v1/trials/{order_id}/cancel
# ════════════════════════════════════════════════════════════════════════════
@router.post(
    "/{order_id}/cancel",
    summary="Cancel a trial before it starts or during the window",
)
async def cancel_trial(
    order_id: str,
    db:       AsyncSession = Depends(get_db),
    _:        str          = Depends(verify_api_key),
):
    """
    Called if the customer cancels before the rider arrives,
    or if the ops team needs to force-close a stuck session.
    """
    from services.redis_client import delete_trial_session
    from models.trial import TrialStatus, TrialSessionDB
    from sqlalchemy import select
    from datetime import datetime, timezone

    session = await get_trial_session(order_id)
    rider_id = session.get("rider_id") if session else None

    # Update DB
    result = await db.execute(
        select(TrialSessionDB).where(TrialSessionDB.order_id == order_id)
    )
    db_row = result.scalar_one_or_none()
    if db_row and db_row.status == TrialStatus.active:
        db_row.status   = TrialStatus.cancelled
        db_row.end_time = datetime.now(timezone.utc)
        await db.commit()

    await delete_trial_session(order_id)

    if rider_id:
        from services.rider_service import mark_rider_available
        await mark_rider_available(rider_id)

    return {"success": True, "order_id": order_id, "message": "Trial cancelled"}