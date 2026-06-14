import sqlite3
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException

from ..db import get_db
from ..models import PackingItem, PackingItemCreate, PackingItemUpdate
from ..repositories.packing_repository import PackingRepository
from ..repositories.trip_repository import TripRepository

router = APIRouter(prefix="/packing", tags=["packing"])


@router.get("", response_model=list[PackingItem])
def list_items(
    trip_id: Optional[str] = None,
    category: Optional[str] = None,
    db: sqlite3.Connection = Depends(get_db),
):
    filters = {
        k: v for k, v in {"trip_id": trip_id, "category": category}.items()
        if v is not None
    }
    repo = PackingRepository(db)
    return [PackingItem(**r) for r in repo.list(filters, order_by=repo.default_order)]


@router.get("/{item_id}", response_model=PackingItem)
def get_item(item_id: str, db: sqlite3.Connection = Depends(get_db)):
    row = PackingRepository(db).get(item_id)
    if row is None:
        raise HTTPException(status_code=404, detail="packing item not found")
    return PackingItem(**row)


@router.post("", response_model=PackingItem, status_code=201)
def create_item(payload: PackingItemCreate, db: sqlite3.Connection = Depends(get_db)):
    if TripRepository(db).get(payload.trip_id) is None:
        raise HTTPException(status_code=400, detail="trip_id does not exist")
    row = PackingRepository(db).create(payload.model_dump())
    return PackingItem(**row)


@router.patch("/{item_id}", response_model=PackingItem)
def update_item(
    item_id: str, payload: PackingItemUpdate, db: sqlite3.Connection = Depends(get_db)
):
    row = PackingRepository(db).update(item_id, payload.model_dump(exclude_unset=True))
    if row is None:
        raise HTTPException(status_code=404, detail="packing item not found")
    return PackingItem(**row)


@router.patch("/{item_id}/packed", response_model=PackingItem)
def toggle_packed(item_id: str, db: sqlite3.Connection = Depends(get_db)):
    repo = PackingRepository(db)
    current = repo.get(item_id)
    if current is None:
        raise HTTPException(status_code=404, detail="packing item not found")
    row = repo.update(item_id, {"is_packed": 0 if current["is_packed"] else 1})
    return PackingItem(**row)


@router.delete("/{item_id}", status_code=204)
def delete_item(item_id: str, db: sqlite3.Connection = Depends(get_db)):
    if not PackingRepository(db).soft_delete(item_id):
        raise HTTPException(status_code=404, detail="packing item not found")
    return None
