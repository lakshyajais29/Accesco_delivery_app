import redis.asyncio as aioredis
import json
import os
from sqlalchemy import text
from database import AsyncSessionLocal

redis_client = aioredis.from_url(os.getenv("REDIS_URL", "redis://localhost:6379"))

async def check_availability(outfit_id: str, size: str, dark_store_id: str):
    cache_key = f"inv:{dark_store_id}:{outfit_id}:{size}"

    # 1. Try Redis cache first (100ms response)
    cached = await redis_client.get(cache_key)
    if cached:
        return json.loads(cached)

    # 2. PostgreSQL fallback
    async with AsyncSessionLocal() as db:
        result = await db.execute(
            text("""
                SELECT quantity, location_bin
                FROM dark_store_inventory
                WHERE dark_store_id = :dark_store_id
                  AND sku = :sku
                  AND size = :size
            """),
            {"dark_store_id": dark_store_id, "sku": outfit_id, "size": size}
        )
        row = result.fetchone()

    data = {
        "available": row[0] > 0 if row else False,
        "quantity": row[0] if row else 0,
        "location": row[1] if row else None
    }

    # 3. Cache for 60 seconds
    await redis_client.setex(cache_key, 60, json.dumps(data))
    return data