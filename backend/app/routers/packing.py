import sqlite3
import uuid
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException

from ..db import get_db
from ..models import PackingItem, PackingItemCreate, PackingItemUpdate

router = APIRouter(prefix="/packing", tags=["packing"])


def _row_to_item(row: sqlite3.Row) -> PackingItem:
    d = dict(row)
    d["is_packed"] = bool(d["is_packed"])
    return PackingItem(**d)


@router.get("", response_model=list[PackingItem])
def list_items(
    trip_id: Optional[str] = None,
    category: Optional[str] = None,
    db: sqlite3.Connection = Depends(get_db),
):
    sql = "SELECT * FROM packing_items"
    where: list[str] = []
    params: list = []
    if trip_id:
        where.append("trip_id = ?"); params.append(trip_id)
    if category:
        where.append("category = ?"); params.append(category)
    if where:
        sql += " WHERE " + " AND ".join(where)
    sql += " ORDER BY sort_order ASC"
    rows = db.execute(sql, params).fetchall()
    return [_row_to_item(r) for r in rows]


@router.get("/{item_id}", response_model=PackingItem)
def get_item(item_id: str, db: sqlite3.Connection = Depends(get_db)):
    row = db.execute("SELECT * FROM packing_items WHERE id = ?", (item_id,)).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="packing item not found")
    return _row_to_item(row)


@router.post("", response_model=PackingItem, status_code=201)
def create_item(payload: PackingItemCreate, db: sqlite3.Connection = Depends(get_db)):
    trip = db.execute("SELECT id FROM trips WHERE id = ?", (payload.trip_id,)).fetchone()
    if not trip:
        raise HTTPException(status_code=400, detail="trip_id does not exist")
    new_id = str(uuid.uuid4())
    db.execute(
        """INSERT INTO packing_items (id, trip_id, category, name, is_packed, sort_order)
           VALUES (?, ?, ?, ?, ?, ?)""",
        (new_id, payload.trip_id, payload.category, payload.name,
         1 if payload.is_packed else 0, payload.sort_order),
    )
    row = db.execute("SELECT * FROM packing_items WHERE id = ?", (new_id,)).fetchone()
    return _row_to_item(row)


@router.patch("/{item_id}", response_model=PackingItem)
def update_item(item_id: str, payload: PackingItemUpdate, db: sqlite3.Connection = Depends(get_db)):
    existing = db.execute("SELECT * FROM packing_items WHERE id = ?", (item_id,)).fetchone()
    if not existing:
        raise HTTPException(status_code=404, detail="packing item not found")
    fields = payload.model_dump(exclude_unset=True)
    if not fields:
        return _row_to_item(existing)
    if "is_packed" in fields:
        fields["is_packed"] = 1 if fields["is_packed"] else 0
    set_clause = ", ".join(f"{k} = ?" for k in fields)
    params = list(fields.values()) + [item_id]
    db.execute(
        f"UPDATE packing_items SET {set_clause}, updated_at = strftime('%Y-%m-%dT%H:%M:%SZ', 'now') WHERE id = ?",
        params,
    )
    row = db.execute("SELECT * FROM packing_items WHERE id = ?", (item_id,)).fetchone()
    return _row_to_item(row)


@router.patch("/{item_id}/packed", response_model=PackingItem)
def toggle_packed(item_id: str, db: sqlite3.Connection = Depends(get_db)):
    row = db.execute("SELECT is_packed FROM packing_items WHERE id = ?", (item_id,)).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="packing item not found")
    new_val = 0 if row["is_packed"] else 1
    db.execute(
        "UPDATE packing_items SET is_packed = ?, updated_at = strftime('%Y-%m-%dT%H:%M:%SZ', 'now') WHERE id = ?",
        (new_val, item_id),
    )
    updated = db.execute("SELECT * FROM packing_items WHERE id = ?", (item_id,)).fetchone()
    return _row_to_item(updated)


@router.delete("/{item_id}", status_code=204)
def delete_item(item_id: str, db: sqlite3.Connection = Depends(get_db)):
    cur = db.execute("DELETE FROM packing_items WHERE id = ?", (item_id,))
    if cur.rowcount == 0:
        raise HTTPException(status_code=404, detail="packing item not found")
    return None
