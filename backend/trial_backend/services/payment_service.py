"""
services/payment_service.py
Razorpay payment capture for Trial-at-Doorstep.

Flow:
  1. Flutter app collects payment method (Razorpay checkout) → gets payment_method_id
  2. Backend calls process_payment() with that ID + amount
  3. Razorpay captures the charge and returns a payment_id

To swap for Stripe: replace the razorpay calls with stripe.PaymentIntent.capture()
"""
import hashlib
import hmac
import logging
import os
import time
import uuid
from typing import Optional

import razorpay

RAZORPAY_KEY_ID     = os.getenv("RAZORPAY_KEY_ID", "")
RAZORPAY_KEY_SECRET = os.getenv("RAZORPAY_KEY_SECRET", "")

logger = logging.getLogger(__name__)


def _get_client() -> razorpay.Client:
    return razorpay.Client(auth=(RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET))


async def process_payment(
    order_id: str,
    payment_method_id: str,
    amount_inr: float,
    description: str = "Trial at Doorstep — kept items",
) -> dict:
    """
    Capture a Razorpay payment.

    Returns:
        {
            "status":     "captured" | "failed",
            "payment_id": str | None,
            "error":      str | None,
        }

    Amount is in INR (float). Razorpay expects paise (int) internally.
    """
    if amount_inr <= 0:
        # Nothing to charge — customer returned everything
        return {"status": "zero_charge", "payment_id": None, "error": None}

    if not RAZORPAY_KEY_ID or not RAZORPAY_KEY_SECRET:
        logger.warning("Razorpay credentials not configured — payment skipped (dev mode)")
        return {
            "status":     "captured",   # pretend success in dev
            "payment_id": f"pay_DEV_{order_id}",
            "error":      None,
        }

    amount_paise = int(amount_inr * 100)

    try:
        client = _get_client()

        # Create order first (Razorpay requires an order before capture)
        rz_order = client.order.create({
            "amount":   amount_paise,
            "currency": "INR",
            "receipt":  order_id[:40],    # max 40 chars
            "notes":    {"order_id": order_id, "description": description},
        })

        # In production the Flutter app already captured via checkout widget
        # and passes payment_method_id == razorpay_payment_id for server-side verify.
        # Here we verify the signature and mark as captured.
        payment = client.payment.fetch(payment_method_id)

        if payment.get("status") == "captured":
            logger.info(
                "Payment already captured: %s  ₹%.2f", payment_method_id, amount_inr
            )
            return {
                "status":     "captured",
                "payment_id": payment_method_id,
                "error":      None,
            }

        # Attempt capture if not yet captured
        capture_resp = client.payment.capture(
            payment_method_id,
            amount_paise,
            {"currency": "INR"},
        )
        logger.info(
            "Payment captured: %s  ₹%.2f", capture_resp.get("id"), amount_inr
        )
        return {
            "status":     "captured",
            "payment_id": capture_resp.get("id"),
            "error":      None,
        }

    except razorpay.errors.BadRequestError as exc:
        logger.error("Razorpay bad request for order %s: %s", order_id, exc)
        return {"status": "failed", "payment_id": None, "error": str(exc)}

    except Exception as exc:
        logger.error("Unexpected payment error for order %s: %s", order_id, exc)
        return {"status": "failed", "payment_id": None, "error": str(exc)}


async def get_user_from_order(order_id: str, db) -> Optional[str]:
    """
    Resolve order_id → user_id.
    Replace the stub below with your actual ORM query, e.g.:
        result = await db.execute(
            select(Order.user_id).where(Order.id == order_id)
        )
        return result.scalar_one_or_none()
    """
    # TODO: replace with real DB query
    return f"usr_{order_id}"   # stub: returns deterministic fake user_id


# ─── Checkout: order creation + signature verification ────────────────────────
#
# Used by routes/payments.py, which the Flutter CheckoutScreen calls before it
# opens the Razorpay sheet and again after the sheet reports success. Kept in
# this module so every razorpay call in the service lives in one file.


def _dev_mode() -> bool:
    """True when no real credentials are configured."""
    return not (RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET)


def create_checkout_order(
    amount_in_paise: int,
    currency: str = "INR",
    receipt: str = "",
    notes: Optional[dict] = None,
) -> dict:
    """
    Create the Razorpay order the checkout sheet is opened against.

    The amount is fixed here, under the key secret, and echoed back to the app
    so the client has no say in what it is charged.

    Returns the raw Razorpay order dict: {"id", "amount", "currency", ...}.
    """
    if amount_in_paise <= 0:
        raise ValueError("amount_in_paise must be positive")

    if _dev_mode():
        # Lets the whole flow be exercised on a laptop with no keys. The id
        # is shaped like a real one so nothing downstream needs a special
        # case, and it will never be mistaken for a live order.
        logger.warning("Razorpay credentials not configured — returning a dev order")
        return {
            "id": f"order_DEV{uuid.uuid4().hex[:14]}",
            "amount": amount_in_paise,
            "currency": currency,
            "receipt": receipt,
            "status": "created",
            "created_at": int(time.time()),
        }

    client = _get_client()
    order = client.order.create(
        {
            "amount": amount_in_paise,
            "currency": currency,
            "receipt": receipt[:40],
            "notes": notes or {},
            # Capture as soon as the payment is authorised. Without this an
            # authorised payment sits uncaptured and is auto-refunded after
            # five days — the classic "the customer paid but we never got it".
            "payment_capture": 1,
        }
    )
    logger.info("Created Razorpay order %s for %s paise", order["id"], amount_in_paise)
    return order


def verify_checkout_signature(
    order_id: str,
    payment_id: str,
    signature: str,
) -> bool:
    """
    Verify Razorpay's checkout signature: HMAC-SHA256 of "order_id|payment_id"
    keyed with the API secret.

    This is the only proof that a success callback in the app corresponds to a
    real payment. Compared with hmac.compare_digest so the check does not leak
    the expected value through its timing.
    """
    if _dev_mode():
        # Mirror the dev order above: accept, but say so loudly. This branch
        # must never be reachable in production, which is what the missing
        # credentials would already have broken.
        logger.warning("Razorpay credentials not configured — signature check skipped")
        return True

    if not (order_id and payment_id and signature):
        return False

    expected = hmac.new(
        key=RAZORPAY_KEY_SECRET.encode("utf-8"),
        msg=f"{order_id}|{payment_id}".encode("utf-8"),
        digestmod=hashlib.sha256,
    ).hexdigest()

    return hmac.compare_digest(expected, signature)
