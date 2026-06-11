"""
services/notification_service.py
Firebase FCM v1 push notifications.

Usage:
    await send_push_notification(
        user_id="usr_abc",
        title="Try it on!",
        body="15 minutes to decide.",
    )
"""
import logging
import os
from typing import Optional

logger = logging.getLogger(__name__)

# ── Lazy-import Firebase Admin so the service boots without credentials ───────
_firebase_initialized = False


def _init_firebase():
    global _firebase_initialized
    if _firebase_initialized:
        return
    try:
        import firebase_admin
        from firebase_admin import credentials
        cred_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
        if cred_path and os.path.exists(cred_path):
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred)
            _firebase_initialized = True
            logger.info("Firebase Admin SDK initialised ✓")
        else:
            logger.warning(
                "GOOGLE_APPLICATION_CREDENTIALS not set — FCM disabled."
            )
    except ImportError:
        logger.warning("firebase-admin not installed — FCM disabled.")


# ── Device token lookup (stub — replace with your DB query) ──────────────────
async def _get_fcm_token(user_id: str) -> Optional[str]:
    """
    In production: query your `user_devices` table for the latest FCM token.
    Example:
        SELECT fcm_token FROM user_devices
        WHERE user_id = :user_id
        ORDER BY updated_at DESC LIMIT 1
    """
    # TODO: replace with real DB lookup
    # Return None to silently skip notification during development
    return None


# ── Public API ────────────────────────────────────────────────────────────────
async def send_push_notification(
    user_id: str,
    title: str,
    body: str,
    data: Optional[dict] = None,
) -> bool:
    """
    Send a push notification to the given user.
    Returns True on success, False on any error (non-fatal).
    """
    _init_firebase()
    if not _firebase_initialized:
        logger.debug("FCM not initialised — skipping push for user %s", user_id)
        return False

    token = await _get_fcm_token(user_id)
    if not token:
        logger.debug("No FCM token for user %s — skipping push", user_id)
        return False

    try:
        from firebase_admin import messaging

        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data=data or {},
            token=token,
            android=messaging.AndroidConfig(priority="high"),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(sound="default", badge=1)
                )
            ),
        )
        response = messaging.send(message)
        logger.info("FCM sent to %s: %s", user_id, response)
        return True

    except Exception as exc:
        # Non-fatal: log and continue — never fail a payment because of FCM
        logger.error("FCM send failed for user %s: %s", user_id, exc)
        return False