import os
import asyncpg
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from prometheus_fastapi_instrumentator import Instrumentator
 
app = FastAPI()
Instrumentator().instrument(app).expose(app)
 
class Item(BaseModel):
    name: str
    value: str = ""
 
 
async def get_db():
    """Open a database connection using credentials from env vars."""
    conn = await asyncpg.connect(
        host=os.environ["DB_HOST"],
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASS"],
        database=os.environ.get("DB_NAME", "appdb"),
    )
    return conn
 
 
@app.get("/health")
def health():
    return {"status": "ok", "service": "python-app"}
 
 
@app.get("/api/stats")
async def stats():
    """Return summary statistics about the items in the database."""
    db = await get_db()
    try:
        count = await db.fetchval("SELECT COUNT(*) FROM items")
        return {"total_items": count, "service": "python-app"}
    finally:
        await db.close()
 
 
@app.post("/api/items")
async def create_item(item: Item):
    """Create a new item in the database."""
    db = await get_db()
    try:
        row = await db.fetchrow(
            "INSERT INTO items(name, value) VALUES($1, $2) RETURNING *",
            item.name,
            item.value,
        )
        return dict(row)
    finally:
        await db.close()
# deployed Sat Mar 14 06:45:51 PM EDT 2026
