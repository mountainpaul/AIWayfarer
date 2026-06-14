# Sync & Soft-Delete Redesign

## Why

A real pending car booking was edited on the phone while the device couldn't
reach the backend; the save failed, and a later sync **destroyed** the local
record. Root cause is architectural, not a one-off bug: the sync treats the
backend as authoritative and is destructive, and nothing is ever soft-deleted.

## Best-practices review of the current DB code

### Backend (`backend/app/…`, SQLite)

| # | Finding | Severity |
|---|---------|----------|
| B1 | **Hard deletes** in `bookings`, `tasks`, `packing` routers (`DELETE FROM …`). No recovery, and a delete on one device can't propagate to others as a tombstone. | Critical |
| B2 | **No `deleted_at`** on any table. | Critical |
| B3 | **`/sync/snapshot` is lossy by design** — it drops past-leg bookings and closed/overdue tasks "to keep payload small." Paired with the client's destructive replace, this *deletes valid local rows the server simply didn't send*. This is exactly what ate the booking. | Critical |
| B4 | **`updated_at` missing** on `journal_entries` and `briefings`; present but **never used for conflict resolution** anywhere. | High |
| B5 | **No incremental sync** — always a full snapshot, no `?since=` delta, no tombstone channel. Forces full-replace semantics on the client. | High |
| B6 | `updated_at` is bumped by hand in each UPDATE's SQL; INSERTs rely on column DEFAULT. Easy to forget on a new write path. A trigger (or a shared helper) is more robust. | Medium |
| B7 | Row→model conversion duplicated across `sync.py` and every router. | Low (DRY) |
| B8 | The `UPDATE … SET {set_clause}` f-string is **not** injectable (keys are Pydantic field names, values are parameterized) — but it depends on that invariant holding. | Low (note) |

Good already: parameterized queries, FK enforcement, CHECK-constrained enums,
money as integer cents, indexes on FKs/dates, connection-per-request with
commit/rollback, `busy_timeout`.

### Frontend (`flutter/lib/services/…`, sqflite)

| # | Finding | Severity |
|---|---------|----------|
| F1 | **`replaceAll` = `DELETE` every row + re-insert the server's rows** (`ConflictAlgorithm.replace`). Server always wins; `updated_at` ignored; local-only and newer-local rows are obliterated. Root cause. | Critical |
| F2 | **No offline write queue** — code comments "Offline write queue is OUT OF SCOPE for v0.5." A save made while disconnected fails and the change is lost. | Critical |
| F3 | **No `deleted_at`** locally; reads don't filter soft-deleted. | Critical |
| F4 | Local DB is `version: 1`, `onCreate` only — **no `onUpgrade`**, so there's no client migration path for new columns. | High |
| F5 | `updated_at` columns exist locally but are unused for merge. | High |

## Design

### Principle
The backend is **not** automatically golden. Every record carries
`created_at`, `updated_at`, `deleted_at`. Sync **merges by `updated_at`
(last-write-wins)** and **never hard-deletes**; deletes are tombstones that
propagate. Local edits made offline are **queued** and pushed on reconnect.

### Schema changes (additive, both ends)
- Add `deleted_at TEXT NULL` to: trips, legs, bookings, tasks, packing_items,
  journal_entries, briefings (and chat_messages once merged).
- Add `updated_at TEXT` to journal_entries, briefings, chat_messages;
  backfill `updated_at = created_at` where null.
- All additive `ALTER TABLE ADD COLUMN` — no existing data is read or rewritten.

### Backend
- **Soft delete:** `DELETE` endpoints set `deleted_at` + bump `updated_at`
  instead of removing the row. (404 only if already absent/already deleted.)
- **Reads** (`list`/`get`) filter `deleted_at IS NULL` by default.
- **Sync becomes delta + tombstone-aware:**
  - `GET /sync/snapshot?since=<iso>` returns every row (including tombstoned
    ones) with `updated_at > since`. No `since` ⇒ full set (still including
    tombstones), and **stop dropping past rows** — completeness over payload
    size for a single-user app.
  - Response includes `deleted_at` on every row and a `server_time` the client
    stores as its next `since` cursor.
- **`updated_at` integrity:** add SQLite triggers so any UPDATE bumps
  `updated_at` automatically (defense-in-depth for B6).

### Frontend
- **`mergeAll` replaces `replaceAll`:** for each incoming row, upsert **only if**
  incoming `updated_at >= local updated_at` (LWW). Tombstoned rows set
  `deleted_at` locally rather than deleting. **Never** delete local rows that
  the server didn't mention.
- **Reads** filter `deleted_at IS NULL`.
- **`onUpgrade`** (bump to `version: 2`) adds the new columns on existing
  installs.
- **Offline outbox:** a `pending_ops` table records local create/update/delete
  intents (entity, id, payload, op, queued_at). On a successful network call the
  op is applied + removed; while offline it's retained and retried on the next
  sync/reconnect. The local row is updated optimistically so the UI reflects the
  change immediately (this is what would have saved the car edit).
- Store the `server_time` cursor in SharedPreferences for delta sync.

### Migration safety
- Backend DB is **backed up first** (done:
  `wayfarer.backup-pre-softdelete-*.db`).
- Every change is additive; no destructive migration, no `unlink`/rebuild.

## Rollout order
1. Backend migration `0004_soft_delete_and_timestamps.sql` (+ triggers).
2. Backend soft-delete + read filters + sync delta/tombstones.
3. Backend tests.
4. Frontend schema `onUpgrade` + `deleted_at`, `mergeAll`, read filters.
5. Frontend offline outbox + delta cursor.
6. `flutter analyze`, `pytest`.
