import sqlite3
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException

from ..db import get_db
from ..models import Task, TaskCreate, TaskUpdate
from ..repositories.leg_repository import LegRepository
from ..repositories.task_repository import TaskRepository

router = APIRouter(prefix="/tasks", tags=["tasks"])


@router.get("", response_model=list[Task])
def list_tasks(
    leg_id: Optional[str] = None,
    is_done: Optional[bool] = None,
    db: sqlite3.Connection = Depends(get_db),
):
    filters: dict = {}
    if leg_id is not None:
        filters["leg_id"] = leg_id
    if is_done is not None:
        filters["is_done"] = 1 if is_done else 0
    repo = TaskRepository(db)
    return [Task(**r) for r in repo.list(filters, order_by=repo.default_order)]


@router.get("/{task_id}", response_model=Task)
def get_task(task_id: str, db: sqlite3.Connection = Depends(get_db)):
    row = TaskRepository(db).get(task_id)
    if row is None:
        raise HTTPException(status_code=404, detail="task not found")
    return Task(**row)


@router.post("", response_model=Task, status_code=201)
def create_task(payload: TaskCreate, db: sqlite3.Connection = Depends(get_db)):
    if payload.leg_id and LegRepository(db).get(payload.leg_id) is None:
        raise HTTPException(status_code=400, detail="leg_id does not exist")
    row = TaskRepository(db).create(payload.model_dump())
    return Task(**row)


@router.patch("/{task_id}", response_model=Task)
def update_task(
    task_id: str, payload: TaskUpdate, db: sqlite3.Connection = Depends(get_db)
):
    row = TaskRepository(db).update(task_id, payload.model_dump(exclude_unset=True))
    if row is None:
        raise HTTPException(status_code=404, detail="task not found")
    return Task(**row)


@router.patch("/{task_id}/done", response_model=Task)
def toggle_done(task_id: str, db: sqlite3.Connection = Depends(get_db)):
    repo = TaskRepository(db)
    current = repo.get(task_id)
    if current is None:
        raise HTTPException(status_code=404, detail="task not found")
    row = repo.update(task_id, {"is_done": 0 if current["is_done"] else 1})
    return Task(**row)


@router.delete("/{task_id}", status_code=204)
def delete_task(task_id: str, db: sqlite3.Connection = Depends(get_db)):
    if not TaskRepository(db).soft_delete(task_id):
        raise HTTPException(status_code=404, detail="task not found")
    return None
