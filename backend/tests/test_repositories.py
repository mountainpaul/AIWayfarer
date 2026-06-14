"""BaseRepository round-trip: create/get/update/soft_delete and the change-log
events each write. Exercises the repository layer directly (no HTTP)."""
import json

from app import config
from app.db import _connect
from app.repositories.base import BaseRepository


class _BookingRepo(BaseRepository):
    table = "booking"
    entity = "booking"


def _conn():
    return _connect(config.DB_PATH)


def test_base_repository_crud_and_changelog():
    conn = _conn()
    try:
        repo = _BookingRepo(conn)
        leg_id = conn.execute("SELECT id FROM leg LIMIT 1").fetchone()["id"]

        # create
        row = repo.create({
            "leg_id": leg_id,
            "type": "other",
            "name": "repo-roundtrip",
            "status": "pending",
            "notes": "first",
        })
        bid = row["id"]
        assert row["name"] == "repo-roundtrip"
        assert repo.get(bid)["notes"] == "first"

        # update records prior value in the change log
        repo.update(bid, {"notes": "second"})
        assert repo.get(bid)["notes"] == "second"

        # soft delete hides it but a get(include_deleted) still finds the row
        assert repo.soft_delete(bid) is True
        assert repo.get(bid) is None
        assert repo.get(bid, include_deleted=True)["deleted_at"] is not None
        # second delete is a no-op (already tombstoned)
        assert repo.soft_delete(bid) is False

        # the change log captured create + update(old=first) + delete
        ops = [
            (r["op"], r["patch"])
            for r in conn.execute(
                "SELECT op, patch FROM change WHERE entity_id = ? ORDER BY seq", (bid,)
            ).fetchall()
        ]
        names = [o for o, _ in ops]
        assert names == ["create", "update", "delete"]
        upd_patch = json.loads(ops[1][1])
        assert upd_patch["old"]["notes"] == "first"
        assert upd_patch["new"]["notes"] == "second"

        conn.commit()
    finally:
        conn.close()
