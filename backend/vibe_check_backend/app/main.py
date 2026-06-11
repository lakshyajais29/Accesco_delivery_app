"""Vibe Check API — FastAPI + Redis + WebSocket."""
from __future__ import annotations

import os
from contextlib import asynccontextmanager

import redis.asyncio as redis
from fastapi import Depends, FastAPI, HTTPException, Request, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse

from .models import (
    CreateVibeCheckRequest,
    CreateVibeCheckResponse,
    ReactRequest,
    ResultsResponse,
    SetStockRequest,
    StockResponse,
    VibeCheck,
)
from .realtime import ConnectionManager, RealtimeBus
from .store import AlreadyVotedError, NotFoundError, Store

REDIS_URL            = os.getenv("REDIS_URL", "redis://localhost:6379/0")
SHARE_BASE_URL       = os.getenv("SHARE_BASE_URL", "https://tattered-yo-yo-duvet.ngrok-free.dev/vote")
LOW_STOCK_THRESHOLD  = int(os.getenv("LOW_STOCK_THRESHOLD", "2"))


@asynccontextmanager
async def lifespan(app: FastAPI):
    client  = redis.from_url(REDIS_URL, decode_responses=True)
    manager = ConnectionManager()
    bus     = RealtimeBus(client, manager)
    await bus.start()

    app.state.redis   = client
    app.state.store   = Store(client)
    app.state.manager = manager
    app.state.bus     = bus
    try:
        yield
    finally:
        await bus.stop()
        await client.aclose()


app = FastAPI(title="InstaStyle Vibe Check API", version="1.0.0", lifespan=lifespan)

# ── MIDDLEWARE — must be declared BEFORE routes ───────────────────────────────

# 1. Bypass ngrok browser-warning interstitial for ALL requests.
#    We inject the header into the *incoming* request scope so ngrok
#    never serves its HTML warning page to Flutter or browser JS.
@app.middleware("http")
async def skip_ngrok_warning(request: Request, call_next):
    # Mutate the incoming headers so ngrok sees the bypass flag.
    headers = dict(request.headers)
    headers["ngrok-skip-browser-warning"] = "true"
    # Rebuild scope headers as a list of byte tuples (ASGI format).
    request.scope["headers"] = [
        (k.lower().encode(), v.encode()) for k, v in headers.items()
    ]
    response = await call_next(request)
    # Also set it on the response so browsers don't get the warning page
    # when they follow redirects or load sub-resources.
    response.headers["ngrok-skip-browser-warning"] = "true"
    return response

# 2. CORS — wide open for demo; tighten in production.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── DEPENDENCIES ──────────────────────────────────────────────────────────────
def get_store() -> Store:
    return app.state.store

def get_bus() -> RealtimeBus:
    return app.state.bus


# ── VIBE CHECKS ───────────────────────────────────────────────────────────────
@app.post("/api/v1/vibe-checks", response_model=CreateVibeCheckResponse)
async def create_vibe_check(
    req: CreateVibeCheckRequest, store: Store = Depends(get_store)
):
    vibe = await store.create_vibe_check(req)
    return CreateVibeCheckResponse(
        poll_id   = vibe.id,
        share_url = f"{SHARE_BASE_URL}/{vibe.id}",
    )


@app.get("/api/v1/vibe-checks/{poll_id}", response_model=VibeCheck)
async def get_vibe_check(poll_id: str, store: Store = Depends(get_store)):
    try:
        return await store.get_vibe_check(poll_id)
    except NotFoundError:
        raise HTTPException(404, "Vibe check not found or expired")


@app.get("/api/v1/vibe-checks/{poll_id}/results", response_model=ResultsResponse)
async def get_results(poll_id: str, store: Store = Depends(get_store)):
    try:
        return await store.get_results(poll_id)
    except NotFoundError:
        raise HTTPException(404, "Vibe check not found or expired")


@app.post("/api/v1/vibe-checks/{poll_id}/react")
async def react(
    poll_id: str,
    req: ReactRequest,
    store: Store = Depends(get_store),
    bus: RealtimeBus   = Depends(get_bus),
):
    try:
        await store.add_reaction(poll_id, req.voter_token, req.reaction)
    except NotFoundError:
        raise HTTPException(404, "Vibe check not found or expired")
    except AlreadyVotedError:
        raise HTTPException(409, "Already reacted")

    results = await store.get_results(poll_id)
    await bus.publish(
        poll_id,
        {
            "type"     : "reactions",
            "poll_id"  : poll_id,
            "reactions": results.reactions,
            "tally"    : results.tally.model_dump(),
        },
    )
    return {"success": True}


# ── PRODUCTS / STOCK ──────────────────────────────────────────────────────────
@app.get("/api/v1/products/{product_id}", response_model=StockResponse)
async def get_stock(product_id: str, store: Store = Depends(get_store)):
    return StockResponse(
        product_id=product_id,
        stock=await store.get_stock(product_id),
    )


@app.post("/api/v1/products/{product_id}/order", response_model=StockResponse)
async def order_product(
    product_id: str,
    store: Store       = Depends(get_store),
    bus: RealtimeBus   = Depends(get_bus),
):
    stock = await store.decrement_stock(product_id, by=1)
    await _broadcast_stock_to_all_polls(product_id, stock, store, bus)
    return StockResponse(product_id=product_id, stock=stock)


@app.put("/api/v1/products/{product_id}/stock", response_model=StockResponse)
async def set_stock(
    product_id: str,
    req: SetStockRequest,
    store: Store       = Depends(get_store),
    bus: RealtimeBus   = Depends(get_bus),
):
    stock = await store.set_stock(product_id, req.stock)
    await _broadcast_stock_to_all_polls(product_id, stock, store, bus)
    return StockResponse(product_id=product_id, stock=stock)


async def _broadcast_stock_to_all_polls(
    product_id: str, stock: int, store: Store, bus: RealtimeBus
):
    message = {
        "type"      : "stock",
        "product_id": product_id,
        "stock"     : stock,
        "low"       : stock <= LOW_STOCK_THRESHOLD,
    }
    async for key in store.r.scan_iter(match="vibe:*", count=100):
        if key.endswith(":reactions"):
            continue
        poll_id = key.split("vibe:", 1)[1]
        try:
            vibe = await store.get_vibe_check(poll_id)
        except NotFoundError:
            continue
        if vibe.product_id == product_id:
            await bus.publish(poll_id, message)


# ── WEBSOCKET ─────────────────────────────────────────────────────────────────
@app.websocket("/ws/vibe-checks/{poll_id}")
async def vibe_check_ws(websocket: WebSocket, poll_id: str):
    manager: ConnectionManager = app.state.manager
    store: Store               = app.state.store
    await manager.connect(poll_id, websocket)
    try:
        try:
            results = await store.get_results(poll_id)
            await websocket.send_json({
                "type"     : "reactions",
                "poll_id"  : poll_id,
                "reactions": results.reactions,
                "tally"    : results.tally.model_dump(),
            })
            vibe  = await store.get_vibe_check(poll_id)
            stock = await store.get_stock(vibe.product_id)
            await websocket.send_json({
                "type"      : "stock",
                "product_id": vibe.product_id,
                "stock"     : stock,
                "low"       : stock <= LOW_STOCK_THRESHOLD,
            })
        except NotFoundError:
            await websocket.send_json({"type": "error", "message": "not_found"})

        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        pass
    finally:
        await manager.disconnect(poll_id, websocket)


# ── FRIEND VOTING PAGE (browser) ──────────────────────────────────────────────
@app.get("/vote/{poll_id}", response_class=HTMLResponse)
async def voting_page(poll_id: str, store: Store = Depends(get_store)):
    try:
        vibe = await store.get_vibe_check(poll_id)
    except NotFoundError:
        return HTMLResponse("""
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Vibe Check Expired</title>
  <style>
    body {{ font-family:'Helvetica Neue',sans-serif; background:#0d0d0d;
           color:white; display:flex; align-items:center; justify-content:center;
           height:100vh; text-align:center; padding:20px; }}
    h2 {{ font-size:22px; margin-bottom:8px; }}
    p  {{ color:#999; font-size:14px; }}
  </style>
</head>
<body>
  <div>
    <div style="font-size:48px;margin-bottom:16px">⏰</div>
    <h2>This Vibe Check has expired.</h2>
    <p>Vibe checks are only active for 24 hours.</p>
  </div>
</body>
</html>
""", status_code=404)

    return HTMLResponse(f"""
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Vibe Check — {vibe.product_name}</title>
  <style>
    * {{ margin:0; padding:0; box-sizing:border-box; }}
    body {{ font-family:'Helvetica Neue',sans-serif; background:#0d0d0d; color:white; min-height:100vh; }}
    .card {{ max-width:420px; margin:0 auto; }}
    .header {{ background:#E91E8C; padding:12px 16px; display:flex; align-items:center; gap:10px; }}
    .header-logo {{ font-size:16px; font-weight:900; letter-spacing:2px; }}
    .header-sub  {{ font-size:10px; letter-spacing:2px; opacity:0.8; margin-left:auto; }}
    .img-wrap {{ position:relative; }}
    .img {{ width:100%; aspect-ratio:3/4; object-fit:cover; display:block; }}
    .img-overlay {{ position:absolute; bottom:0; left:0; right:0;
                    background:linear-gradient(transparent,rgba(0,0,0,0.85));
                    padding:24px 16px 16px; }}
    .from-tag    {{ background:#E91E8C; color:white; font-size:11px; font-weight:700;
                    letter-spacing:1px; padding:4px 10px; display:inline-block; margin-bottom:8px; }}
    .product-name {{ font-size:26px; font-weight:900; letter-spacing:0.5px; }}
    .product-cat  {{ font-size:13px; color:#ccc; margin-top:2px; }}
    .voting {{ padding:20px 16px; }}
    .ask {{ font-size:15px; font-weight:600; margin-bottom:16px; color:#eee; }}
    .buttons {{ display:flex; gap:10px; }}
    .btn {{ flex:1; padding:18px 8px; border:none; font-size:13px; font-weight:700;
            letter-spacing:1px; cursor:pointer; border-radius:2px;
            transition:transform 0.1s,opacity 0.1s; }}
    .btn:active {{ transform:scale(0.96); opacity:0.85; }}
    .yes   {{ background:#E91E8C; color:white; }}
    .maybe {{ background:#FF6F00; color:white; }}
    .no    {{ background:#555;    color:white; }}
    .result {{ display:none; padding:24px 16px; text-align:center; }}
    .result.show {{ display:block; }}
    .result-emoji {{ font-size:56px; margin-bottom:14px; }}
    .result-title {{ font-size:20px; font-weight:800; margin-bottom:6px; }}
    .result-sub   {{ font-size:13px; color:#999; }}
    .result-card  {{ background:#1a1a1a; border-radius:8px; padding:16px;
                     margin-top:20px; display:flex; align-items:center; gap:14px; }}
    .result-img   {{ width:56px; height:70px; object-fit:cover; border-radius:2px; flex-shrink:0; }}
    .result-info  {{ text-align:left; }}
    .result-pname {{ font-size:13px; font-weight:700; margin-bottom:2px; }}
    .result-pcat  {{ font-size:11px; color:#999; }}
    .error-msg {{ display:none; color:#ff4444; font-size:13px;
                  margin-top:12px; text-align:center; }}
    .error-msg.show {{ display:block; }}
    .footer {{ padding:16px; text-align:center; border-top:1px solid #1a1a1a; margin-top:8px; }}
    .footer span {{ font-size:11px; color:#555; letter-spacing:1px; }}
  </style>
</head>
<body>
<div class="card">
  <div class="header">
    <span class="header-logo">INSTASTYLE</span>
    <span class="header-sub">VIBE CHECK</span>
  </div>
  <div class="img-wrap">
    <img class="img" src="{vibe.product_image}" alt="{vibe.product_name}"
         onerror="this.style.background='#1a1a1a';this.removeAttribute('src')"/>
    <div class="img-overlay">
      <div class="from-tag">{vibe.creator_name} wants your take 👀</div>
      <div class="product-name">{vibe.product_name}</div>
      <div class="product-cat">{vibe.product_category}</div>
    </div>
  </div>
  <div class="voting" id="voting-section">
    <div class="ask">Should they get it?</div>
    <div class="buttons">
      <button class="btn yes"   onclick="vote('YES')">🔥 YES</button>
      <button class="btn maybe" onclick="vote('MAYBE')">🤔 MAYBE</button>
      <button class="btn no"    onclick="vote('NO')">❌ NO</button>
    </div>
    <div class="error-msg" id="error-msg">Something went wrong. Please try again.</div>
  </div>
  <div class="result" id="result-section">
    <div class="result-emoji" id="result-emoji"></div>
    <div class="result-title" id="result-title"></div>
    <div class="result-sub"   id="result-sub"></div>
    <div class="result-card">
      <img class="result-img" src="{vibe.product_image}" alt="{vibe.product_name}"
           onerror="this.style.background='#333';this.removeAttribute('src')"/>
      <div class="result-info">
        <div class="result-pname">{vibe.product_name}</div>
        <div class="result-pcat">{vibe.product_category}</div>
      </div>
    </div>
  </div>
  <div class="footer"><span>POWERED BY INSTASTYLE</span></div>
</div>

<script>
  const POLL_ID = "{poll_id}";
  const token   = "web_" + Math.random().toString(36).substr(2, 9);

  const reactions = {{
    YES:   {{ emoji: "🔥", title: "You said YES!",   sub: "{vibe.creator_name} can see your reaction live." }},
    MAYBE: {{ emoji: "🤔", title: "You said MAYBE.", sub: "Noted — you're on the fence!" }},
    NO:    {{ emoji: "❌", title: "You said NO.",     sub: "Thanks for being honest!" }},
  }};

  async function vote(reaction) {{
    document.querySelectorAll('.btn').forEach(b => b.disabled = true);
    document.getElementById('error-msg').classList.remove('show');
    try {{
      const res = await fetch(`/api/v1/vibe-checks/${{POLL_ID}}/react`, {{
        method : 'POST',
        headers: {{
          'Content-Type'              : 'application/json',
          'ngrok-skip-browser-warning': 'true',
        }},
        body: JSON.stringify({{ voter_token: token, reaction }}),
      }});
      if (!res.ok && res.status !== 409) throw new Error('Server error ' + res.status);
      const r = reactions[reaction];
      document.getElementById('result-emoji').innerText = r.emoji;
      document.getElementById('result-title').innerText = r.title;
      document.getElementById('result-sub').innerText   = r.sub;
      document.getElementById('voting-section').style.display = 'none';
      document.getElementById('result-section').classList.add('show');
    }} catch (e) {{
      document.querySelectorAll('.btn').forEach(b => b.disabled = false);
      document.getElementById('error-msg').classList.add('show');
    }}
  }}
</script>
</body>
</html>
""")


# ── HEALTH ────────────────────────────────────────────────────────────────────
@app.get("/health")
async def health():
    return {{"status": "ok"}}