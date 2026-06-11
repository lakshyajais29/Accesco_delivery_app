"""End-to-end test of the create -> react -> results -> stock/FOMO flow,
plus the WebSocket broadcast and double-vote rejection.

Run: python -m pytest test_flow.py  (uses fakeredis, no server needed)
"""
import asyncio
import json

import fakeredis.aioredis
import pytest
from httpx import ASGITransport, AsyncClient

import app.main as main_module
from app.main import app
from app.realtime import ConnectionManager, RealtimeBus
from app.store import Store


@pytest.fixture
async def client():
    # Swap the real Redis for an in-memory fake and wire app.state by hand
    # (bypassing the lifespan, which would try to reach a real server).
    r = fakeredis.aioredis.FakeRedis(decode_responses=True)
    manager = ConnectionManager()
    bus = RealtimeBus(r, manager)
    await bus.start()
    app.state.redis = r
    app.state.store = Store(r)
    app.state.manager = manager
    app.state.bus = bus

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c

    await bus.stop()
    await r.aclose()


def _create_payload():
    return {
        "product_id": "saree_maison_kaira_001",
        "product_name": "MAISON KAIRA",
        "product_category": "Festive Saree",
        "product_price": "₹18,500",
        "product_image": "https://example.com/x.jpg",
        "product_stock": 5,
        "creator_id": "priya_uid",
        "creator_name": "Priya",
        "selected_friend_ids": ["a", "b", "c"],
    }


@pytest.mark.asyncio
async def test_create_react_results(client):
    res = await client.post("/api/v1/vibe-checks", json=_create_payload())
    assert res.status_code == 200
    poll_id = res.json()["poll_id"]
    assert res.json()["share_url"].endswith(poll_id)

    # three friends react
    for token, reaction in [("a", "YES"), ("b", "YES"), ("c", "MAYBE")]:
        r = await client.post(
            f"/api/v1/vibe-checks/{poll_id}/react",
            json={"voter_token": token, "reaction": reaction},
        )
        assert r.status_code == 200

    results = (await client.get(f"/api/v1/vibe-checks/{poll_id}/results")).json()
    assert results["tally"] == {"YES": 2, "MAYBE": 1, "NO": 0, "total": 3}
    assert results["reactions"] == {"a": "YES", "b": "YES", "c": "MAYBE"}


@pytest.mark.asyncio
async def test_double_vote_rejected(client):
    poll_id = (
        await client.post("/api/v1/vibe-checks", json=_create_payload())
    ).json()["poll_id"]

    first = await client.post(
        f"/api/v1/vibe-checks/{poll_id}/react",
        json={"voter_token": "a", "reaction": "YES"},
    )
    assert first.status_code == 200

    second = await client.post(
        f"/api/v1/vibe-checks/{poll_id}/react",
        json={"voter_token": "a", "reaction": "NO"},
    )
    assert second.status_code == 409  # Already reacted


@pytest.mark.asyncio
async def test_stock_and_fomo(client):
    payload = _create_payload()
    pid = payload["product_id"]
    await client.post("/api/v1/vibe-checks", json=payload)

    assert (await client.get(f"/api/v1/products/{pid}")).json()["stock"] == 5

    # drop stock to the FOMO zone
    r = await client.put(f"/api/v1/products/{pid}/stock", json={"stock": 2})
    assert r.json()["stock"] == 2

    # ordering decrements
    r = await client.post(f"/api/v1/products/{pid}/order")
    assert r.json()["stock"] == 1


@pytest.mark.asyncio
async def test_websocket_receives_live_reaction(client):
    # Verify the bus forwards a published reaction to a local socket.
    poll_id = (
        await client.post("/api/v1/vibe-checks", json=_create_payload())
    ).json()["poll_id"]

    received = []

    class FakeWS:
        async def send_json(self, msg):
            received.append(msg)

    ws = FakeWS()
    await app.state.manager.connect_raw(poll_id, ws) if hasattr(
        app.state.manager, "connect_raw"
    ) else app.state.manager._conns.setdefault(poll_id, set()).add(ws)

    await client.post(
        f"/api/v1/vibe-checks/{poll_id}/react",
        json={"voter_token": "a", "reaction": "YES"},
    )
    # give the pub/sub listener a moment to deliver
    await asyncio.sleep(0.2)

    assert any(
        m.get("type") == "reactions" and m["tally"]["YES"] == 1 for m in received
    ), received