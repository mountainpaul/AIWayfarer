import sqlite3
import uuid
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException

from ..db import get_db
from ..models import Task, TaskCreate, TaskUpdate

router = APIRouter(prefix="/tasks", tags=["tasks"])


def _row_to_task(row: sqlite3.Row) -> Task:
    d = dict(row)
    d["is_done"] = bool(d["is_done"])
    return Task(**d)


@router.get("", response_model=list[Task])
def list_tasks(
    leg_id: Optional[str] = None,
    is_done: Optional[bool] = None,
    db: sqlite3.Connection = Depends(get_db),
):
    sql = "SELECT * FROM tasks"
    where: list[str] = []
    params: list = []
    if leg_id:
        where.append("leg_id = ?"); params.append(leg_id)
    if is_done is not None:
        where.append("is_done = ?"); params.append(1 if is_done else 0)
    if where:
        sql += " WHERE " + " AND ".join(where)
    sql += """ ORDER BY CASE priority
                  WHEN 'critical' THEN 0 WHEN 'high' THEN 1
                  WHEN 'medium' THEN 2 WHEN 'low' THEN 3 END,
                COALESCE(due_date, '9999') ASC"""
    rows = db.execute(sql, params).fetchall()
    return [_row_to_task(r) for r in rows]


@router.get("/{task_id}", response_model=Task)
def get_task(task_id: str, db: sqlite3.Connection = Depends(get_db)):
    row = db.execute("SELECT * FROM tasks WHERE id = ?", (task_id,)).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="task not found")
    return _row_to_task(row)


@router.post("", response_model=Task, status_code=201)
def create_task(payload: TaskCreate, db: sqlite3.Connection = Depends(get_db)):
    if payload.leg_id:
        leg = db.execute("SELECT id FROM legs WHERE id = ?", (payload.leg_id,)).fetchone()
        if not leg:
            raise HTTPException(status_code=400, detail="leg_id does not exist")
    new_id = str(uuid.uuid4())
    db.execute(
        """INSERT INTO tasks (id, leg_id, title, priority, due_date, is_done, notes)
           VALUES (?, ?, ?, ?, ?, ?, ?)""",
        (new_id, payload.leg_id, payload.title, payload.priority,
         payload.due_date, 1 if payload.is_done else 0, payload.notes),
    )
    row = db.execute("SELECT * FROM tasks WHERE id = ?", (new_id,)).fetchone()
    return _row_to_task(row)


@router.patch("/{task_id}", response_model=Task)
def update_task(task_id: str, payload: TaskUpdate, db: sqlite3.Connection = Depends(get_db)):
    existing = db.execute("SELECT * FROM tasks WHERE id = ?", (task_id,)).fetchone()
    if not existing:
        raise HTTPException(status_code=404, detail="task not found")
    fields = payload.model_dump(exclude_unset=True)
    if not fields:
        return _row_to_task(existing)
    if "is_done" in fields:
        fields["is_done"] = 1 if fields["is_done"] else 0
    set_clause = ", ".join(f"{k} = ?" for k in fields)
    params = list(fields.values()) + [task_id]
    db.execute(
        f"UPDATE tasks SET {set_clause}, updated_at = strftime('%Y-%m-%dT%H:%M:%SZ', 'now') WHERE id = ?",
        params,
    )
    row = db.execute("SELECT * FROM tasks WHERE id = ?", (task_id,)).fetchone()
    return _row_to_task(row)


@router.patch("/{task_id}/done", response_model=Task)
def toggle_done(task_id: str, db: sqlite3.Connection = Depends(get_db)):
    row = db.execute("SELECT is_done FROM tasks WHERE id = ?", (task_id,)).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="task not found")
    new_val = 0 if row["is_done"] else 1
    db.execute(
        "UPDATE tasks SET is_done = ?, updated_at = strftime('%Y-%m-%dT%H:%M:%SZ', 'now') WHERE id = ?",
        (new_val, task_id),
    )
    updated = db.execute("SELECT * FROM tasks WHERE id = ?", (task_id,)).fetchone()
    return _row_to_task(updated)


@router.delete("/{task_id}", status_code=204)
def delete_task(task_id: str, db: sqlite3.Connection = Depends(get_db)):
    cur = db.execute("DELETE FROM tasks WHERE id = ?", (task_id,))
    if cur.rowcount == 0:
        raise HTTPException(status_code=404, detail="task not found")
    return None
