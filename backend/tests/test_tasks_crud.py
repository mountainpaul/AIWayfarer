from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def _dolomites_leg_id() -> str:
    legs = client.get("/api/v1/legs").json()
    return next(l["id"] for l in legs if l["slug"] == "dolomites")


def test_create_task_with_default_priority():
    created = client.post("/api/v1/tasks", json={"title": "Untitled task"}).json()
    try:
        assert created["priority"] == "medium"
        assert created["is_done"] is False
        assert created["leg_id"] is None
    finally:
        client.delete(f"/api/v1/tasks/{created['id']}")


def test_create_task_rejects_unknown_leg():
    r = client.post(
        "/api/v1/tasks",
        json={"leg_id": "00000000-0000-0000-0000-000000000000", "title": "x"},
    )
    assert r.status_code == 400


def test_toggle_done_flips_value():
    created = client.post("/api/v1/tasks", json={
        "title": "Toggle me", "priority": "high", "leg_id": _dolomites_leg_id(),
    }).json()
    try:
        assert created["is_done"] is False

        first = client.patch(f"/api/v1/tasks/{created['id']}/done").json()
        assert first["is_done"] is True

        second = client.patch(f"/api/v1/tasks/{created['id']}/done").json()
        assert second["is_done"] is False
    finally:
        client.delete(f"/api/v1/tasks/{created['id']}")


def test_toggle_done_404_for_unknown_id():
    r = client.patch("/api/v1/tasks/does-not-exist/done")
    assert r.status_code == 404


def test_patch_task_updates_priority_and_due_date():
    created = client.post("/api/v1/tasks", json={"title": "Priority shift"}).json()
    try:
        r = client.patch(
            f"/api/v1/tasks/{created['id']}",
            json={"priority": "critical", "due_date": "2026-05-01"},
        )
        assert r.status_code == 200
        body = r.json()
        assert body["priority"] == "critical"
        assert body["due_date"] == "2026-05-01"
        assert body["title"] == "Priority shift"
    finally:
        client.delete(f"/api/v1/tasks/{created['id']}")


def test_filter_tasks_by_done_status():
    created = client.post("/api/v1/tasks", json={"title": "Filter test"}).json()
    try:
        client.patch(f"/api/v1/tasks/{created['id']}/done")
        done = client.get("/api/v1/tasks?is_done=true").json()
        assert any(t["id"] == created["id"] for t in done)
        not_done = client.get("/api/v1/tasks?is_done=false").json()
        assert all(t["id"] != created["id"] for t in not_done)
    finally:
        client.delete(f"/api/v1/tasks/{created['id']}")
