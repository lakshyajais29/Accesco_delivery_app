"""
services/trial_service.py
Orchestrates the full Trial-at-Doorstep lifecycle:

  start_trial_session()  →  POST /api/v1/trials/{order_id}/start
  keep_outfit()          →  POST /api/v1/trials/{order_id}/keep
  expire_trial()         →  called by APScheduler background job
"""
import logging
import time
from datetime import datetime, timezone

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from models.trial import TrialSessionDB, TrialStatus
from services.redis_client import (
    set_trial_session,
    get_trial_session,
    delete_trial_session,
    acquire_lock,
    release_lock,
)
from services.notification_service import send_push_notification
from services.rider_service import mark_rider_busy, mark_rider_available
from services.payment_service import process_payment, get_user_from_order

import os

TRIAL_DURATION_SECONDS = int(os.getenv("TRIAL_DURATION_SECONDS", "900"))

logger = logging.getLogger(__name__)


# ══════════════════════════════════════════════════════════════════════════════
# START TRIAL SESSION
# Matches spec:  POST /api/v1/trials/{order_id}/start
#
# @app.post("/api/v1/trials/{order_id}/start")
# async def start_trial_session(order_id: str, rider_id: str):
#     trial_data = {"order_id": ..., "rider_id": ..., "start_time": ..., "status": "active"}
#     redis_client.setex(f"trial:{order_id}", 900, json.dumps(trial_data))
#     await send_push_notification(user_id=..., title="Try it on!", body="15 minutes to decide.")
#     return {"session_started": True}
# ══════════════════════════════════════════════════════════════════════════════
async def start_trial_session(
    order_id: str,
    rider_id: str,
    items: list[dict],
    db: AsyncSession,
) -> dict:
    """
    1. Check no active session already exists (idempotent re-start is fine).
    2. Write Redis session with 15-min TTL.
    3. Persist initial row to PostgreSQL.
    4. Mark rider as busy.
    5. Send 'Try it on!' push notification.
    """

    # ── Idempotency: if session already active, return it ────────────────────
    existing = await get_trial_session(order_id)
    if existing and existing.get("status") == "active":
        logger.info("Trial session already active for order %s", order_id)
        return {
            "session_started": True,
            "order_id":        order_id,
            "rider_id":        rider_id,
            "duration_seconds": TRIAL_DURATION_SECONDS,
            "start_time":      existing["start_time"],
            "message":         "Session already active",
        }

    # ── Resolve user_id from order (your OMS / DB) ───────────────────────────
    user_id = await get_user_from_order(order_id, db)

    start_time = datetime.now(timezone.utc).isoformat()

    # ── 1. Write Redis session (TTL = TRIAL_DURATION_SECONDS) ────────────────
    trial_data = {
        "order_id":   order_id,
        "rider_id":   rider_id,
        "user_id":    user_id,
        "start_time": start_time,
        "status":     "active",
        "items":      items,       # [{variant_sku, product_name, unit_price_inr}]
    }
    await set_trial_session(order_id, trial_data)
    logger.info("Redis trial session created for order %s (TTL %ds)", order_id, TRIAL_DURATION_SECONDS)

    # ── 2. Persist to PostgreSQL ─────────────────────────────────────────────
    db_session = TrialSessionDB(
        order_id   = order_id,
        rider_id   = rider_id,
        user_id    = user_id or "unknown",
        status     = TrialStatus.active,
        start_time = datetime.fromisoformat(start_time),
    )
    db.add(db_session)
    await db.commit()
    logger.info("PostgreSQL trial record created for order %s", order_id)

    # ── 3. Mark rider busy (non-fatal) ───────────────────────────────────────
    await mark_rider_busy(rider_id=rider_id, order_id=order_id)

    # ── 4. Send push notification (non-fatal) ────────────────────────────────
    if user_id:
        await send_push_notification(
            user_id = user_id,
            title   = "Try it on!",
            body    = "15 minutes to decide. Your rider is waiting.",
            data    = {"order_id": order_id, "screen": "trial_timer"},
        )

    return {
        "session_started":  True,
        "order_id":         order_id,
        "rider_id":         rider_id,
        "duration_seconds": TRIAL_DURATION_SECONDS,
        "start_time":       start_time,
        "message":          "Trial session started successfully",
    }


# ══════════════════════════════════════════════════════════════════════════════
# KEEP OUTFIT  (CONFIRM & PAY)
# Matches spec:  POST /api/v1/trials/{order_id}/keep
#
# @app.post("/api/v1/trials/{order_id}/keep")
# async def keep_outfit(order_id: str):
#     await process_payment(order_id)
#     await update_order_status(order_id, 'completed')
#     await rider_service.mark_available(rider_id)
#     return {"success": True}
# ══════════════════════════════════════════════════════════════════════════════
async def keep_outfit(
    order_id: str,
    kept_skus: list[str],
    payment_method_id: str | None,
    db: AsyncSession,
) -> dict:
    """
    1. Acquire distributed lock (prevents double-payment).
    2. Validate session is active in Redis.
    3. Calculate total for kept items only.
    4. Process payment (Razorpay capture).
    5. Update PostgreSQL record to 'completed'.
    6. Release Redis session.
    7. Mark rider available.
    8. Return summary.
    """

    # ── 1. Distributed lock — prevents double-tap race condition ─────────────
    lock_acquired = await acquire_lock(order_id, ttl=30)
    if not lock_acquired:
        raise ValueError("Payment already in progress for this order. Please wait.")

    try:
        # ── 2. Validate Redis session ─────────────────────────────────────────
        session = await get_trial_session(order_id)
        if not session:
            raise ValueError(f"No active trial session for order {order_id}. Session may have expired.")

        if session.get("status") != "active":
            raise ValueError(f"Trial session is not active (status: {session.get('status')}).")

        rider_id = session["rider_id"]
        user_id  = session.get("user_id")
        all_items: list[dict] = session.get("items", [])

        # ── 3. Compute kept vs returned ───────────────────────────────────────
        kept_set      = set(kept_skus)
        kept_items    = [i for i in all_items if i["variant_sku"] in kept_set]
        returned_items= [i for i in all_items if i["variant_sku"] not in kept_set]
        total_inr     = sum(i["unit_price_inr"] for i in kept_items)

        logger.info(
            "Order %s: keeping %d items (₹%.2f), returning %d",
            order_id, len(kept_items), total_inr, len(returned_items)
        )

        # ── 4. Process payment ────────────────────────────────────────────────
        payment_result = {"status": "zero_charge", "payment_id": None, "error": None}

        if kept_items:
            if not payment_method_id:
                raise ValueError("payment_method_id required when keeping items.")
            payment_result = await process_payment(
                order_id          = order_id,
                payment_method_id = payment_method_id,
                amount_inr        = total_inr,
                description       = f"Trial keep — {len(kept_items)} item(s)",
            )
            if payment_result["status"] == "failed":
                raise RuntimeError(
                    f"Payment failed: {payment_result.get('error', 'Unknown error')}"
                )

        # ── 5. Update PostgreSQL ──────────────────────────────────────────────
        result = await db.execute(
            select(TrialSessionDB).where(TrialSessionDB.order_id == order_id)
        )
        db_row = result.scalar_one_or_none()

        if db_row:
            db_row.status         = TrialStatus.completed
            db_row.end_time       = datetime.now(timezone.utc)
            db_row.kept_items     = [i["variant_sku"] for i in kept_items]
            db_row.returned_items = [i["variant_sku"] for i in returned_items]
            db_row.total_charged  = total_inr
            await db.commit()
            logger.info("PostgreSQL trial record updated to 'completed' for order %s", order_id)
        else:
            logger.warning("No PostgreSQL row found for order %s during keep_outfit", order_id)

        # ── 6. Clear Redis session ────────────────────────────────────────────
        await delete_trial_session(order_id)

        # ── 7. Release rider ──────────────────────────────────────────────────
        await mark_rider_available(rider_id)

        # ── 8. Send confirmation push ─────────────────────────────────────────
        if user_id and kept_items:
            await send_push_notification(
                user_id = user_id,
                title   = "Payment successful! 🎉",
                body    = f"₹{total_inr:,.0f} charged for {len(kept_items)} kept item(s).",
                data    = {"order_id": order_id, "screen": "order_confirmation"},
            )
        elif user_id and not kept_items:
            await send_push_notification(
                user_id = user_id,
                title   = "All returned — no charge!",
                body    = "Your rider has collected everything. See you next time.",
                data    = {"order_id": order_id},
            )

        return {
            "success":           True,
            "order_id":          order_id,
            "kept_count":        len(kept_items),
            "returned_count":    len(returned_items),
            "total_charged_inr": total_inr,
            "payment_status":    payment_result["status"],
            "message":           "Trial completed successfully",
        }

    finally:
        # Always release the lock
        await release_lock(order_id)


# ══════════════════════════════════════════════════════════════════════════════
# EXPIRE TRIAL  (called by background scheduler when Redis TTL fires)
# ══════════════════════════════════════════════════════════════════════════════
async def expire_trial(order_id: str, db: AsyncSession) -> None:
    """
    Marks the session as expired in PostgreSQL and releases the rider.
    Called by the APScheduler background job (see routes/trials.py).
    """
    session = await get_trial_session(order_id)
    if not session:
        return  # already closed

    rider_id = session.get("rider_id")
    user_id  = session.get("user_id")

    # Update DB
    result = await db.execute(
        select(TrialSessionDB).where(TrialSessionDB.order_id == order_id)
    )
    db_row = result.scalar_one_or_none()
    if db_row and db_row.status == TrialStatus.active:
        db_row.status   = TrialStatus.expired
        db_row.end_time = datetime.now(timezone.utc)
        await db.commit()

    await delete_trial_session(order_id)

    if rider_id:
        await mark_rider_available(rider_id)

    if user_id:
        await send_push_notification(
            user_id = user_id,
            title   = "Trial time's up ⏰",
            body    = "Your rider has left. Order again anytime!",
            data    = {"order_id": order_id},
        )

    logger.info("Trial session %s expired and closed", order_id)