"""
routes/payments.py
FastAPI router — Razorpay checkout endpoints for the unified Flutter checkout.

POST /api/v1/payments/orders   -> create a Razorpay order, return its id + key_id
POST /api/v1/payments/verify   -> HMAC-verify the signature the app got back

Why the app cannot do either of these itself:

  * Creating the order is the only moment the amount can be fixed somewhere
    the client cannot reach. A checkout opened with a client-chosen amount is
    a checkout the client can rewrite.
  * Verifying the signature needs the key *secret*, which must never ship in
    an APK. The success callback in the app is a claim; this endpoint is what
    turns it into evidence.

The key_id is returned to the app rather than compiled into it so that
rotating keys, or moving from rzp_test_ to rzp_live_, does not need a release.
"""
import logging
import os

from fastapi import APIRouter, Depends, HTTPException, Header
from pydantic import BaseModel, Field

from services.payment_service import (
    RAZORPAY_KEY_ID,
    create_checkout_order,
    verify_checkout_signature,
)

router = APIRouter()
logger = logging.getLogger(__name__)


# ── Auth — same simple API key the trials router uses ────────────────────────
async def verify_api_key(x_api_key: str = Header(..., alias="X-API-Key")):
    expected = os.getenv("INTERNAL_API_KEY", "dev-key-change-me")
    if x_api_key != expected:
        raise HTTPException(status_code=401, detail="Invalid API key")
    return x_api_key


# ── Schemas ──────────────────────────────────────────────────────────────────
class CreateOrderRequest(BaseModel):
    # Paise, never rupees. Razorpay's own unit, and it keeps float rounding
    # out of a number that becomes a charge.
    amount_in_paise: int = Field(..., gt=0, le=100_000_000)
    currency: str = Field(default="INR", max_length=3)
    receipt: str = Field(..., max_length=40)
    notes: dict[str, str] = Field(default_factory=dict)


class CreateOrderResponse(BaseModel):
    order_id: str
    amount: int
    currency: str
    key_id: str


class VerifyRequest(BaseModel):
    razorpay_order_id: str
    razorpay_payment_id: str
    razorpay_signature: str


class VerifyResponse(BaseModel):
    verified: bool
    order_id: str
    payment_id: str


# ════════════════════════════════════════════════════════════════════════════
# POST /api/v1/payments/orders
# ════════════════════════════════════════════════════════════════════════════
@router.post(
    "/orders",
    response_model=CreateOrderResponse,
    summary="Create a Razorpay order for the checkout sheet",
)
async def create_order(
    body: CreateOrderRequest,
    _: str = Depends(verify_api_key),
):
    try:
        order = create_checkout_order(
            amount_in_paise=body.amount_in_paise,
            currency=body.currency,
            receipt=body.receipt,
            notes=body.notes,
        )
    except Exception as exc:
        logger.error("Razorpay order creation failed: %s", exc)
        # 502, not 500: the failure is upstream at the gateway, and the app's
        # retry copy ("please try again") is the right response to it.
        raise HTTPException(
            status_code=502, detail="Could not create payment order"
        ) from exc

    return CreateOrderResponse(
        order_id=order["id"],
        amount=order["amount"],
        currency=order["currency"],
        key_id=RAZORPAY_KEY_ID or "rzp_test_dev",
    )


# ════════════════════════════════════════════════════════════════════════════
# POST /api/v1/payments/verify
# ════════════════════════════════════════════════════════════════════════════
@router.post(
    "/verify",
    response_model=VerifyResponse,
    summary="Verify the signature returned by the Razorpay checkout",
)
async def verify_payment(
    body: VerifyRequest,
    _: str = Depends(verify_api_key),
):
    verified = verify_checkout_signature(
        order_id=body.razorpay_order_id,
        payment_id=body.razorpay_payment_id,
        signature=body.razorpay_signature,
    )

    if not verified:
        # A definite rejection, which the app treats as "do not create this
        # order" — distinct from a 5xx, which it treats as "could not ask"
        # and records as pending_verification for the webhook to settle.
        logger.warning(
            "Signature mismatch for order %s / payment %s",
            body.razorpay_order_id,
            body.razorpay_payment_id,
        )
        raise HTTPException(status_code=400, detail="Signature verification failed")

    return VerifyResponse(
        verified=True,
        order_id=body.razorpay_order_id,
        payment_id=body.razorpay_payment_id,
    )
