"""
Accesco Living — Trial at Doorstep  |  Backend Service
FastAPI · Redis · PostgreSQL · Firebase FCM
"""

from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routes.trials import router as trial_router
from services.redis_client import redis_client
from services.db import engine, Base


# ── Startup / Shutdown ────────────────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Create all tables on start (use Alembic migrations in prod)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    await redis_client.close()


# ── App ───────────────────────────────────────────────────────────────────────
app = FastAPI(
    title="Accesco Living – Trial at Doorstep API",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],        # tighten in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(trial_router, prefix="/api/v1/trials", tags=["Trials"])


@app.get("/health")
async def health():
    return {"status": "ok", "service": "trial-at-doorstep"}