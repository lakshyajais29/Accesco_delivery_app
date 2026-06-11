"""
services/rider_service.py
HTTP client for the Rider microservice.

Endpoints called:
  POST /riders/{rider_id}/available   — free the rider after trial ends
  POST /riders/{rider_id}/busy        — mark busy when trial starts
"""
import logging
import os

import httpx

RIDER_SERVICE_URL = os.getenv("RIDER_SERVICE_URL", "http://localhost:8001")
_TIMEOUT = 5.0  # seconds — non-fatal if rider service is slow

logger = logging.getLogger(__name__)


async def mark_rider_busy(rider_id: str, order_id: str) -> bool:
    """
    Called when a trial session starts so the rider is locked to this order.
    Returns True on success, False on any error (non-fatal).
    """
    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
            resp = await client.post(
                f"{RIDER_SERVICE_URL}/riders/{rider_id}/busy",
                json={"order_id": order_id},
            )
            resp.raise_for_status()
            logger.info("Rider %s marked busy for order %s", rider_id, order_id)
            return True
    except Exception as exc:
        # Non-fatal: rider dispatch still happened via OMS; this is a status sync
        logger.warning("mark_rider_busy failed for %s: %s", rider_id, exc)
        return False


async def mark_rider_available(rider_id: str) -> bool:
    """
    Called when trial ends (keep OR return) to release the rider.
    Returns True on success, False on any error (non-fatal).
    """
    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
            resp = await client.post(
                f"{RIDER_SERVICE_URL}/riders/{rider_id}/available",
            )
            resp.raise_for_status()
            logger.info("Rider %s marked available", rider_id)
            return True
    except Exception as exc:
        logger.warning("mark_rider_available failed for %s: %s", rider_id, exc)
        return False