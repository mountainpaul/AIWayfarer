# Sync v2 — Server-Side Change Log (+ client idempotency)

Builds on v1 (`sync-redesign.md`, shipped: soft-delete, timestamps, merge sync,
offline outbox). v1 preserves only the *last* state of a row. v2 preserves the
**full history of changes**, which is what enables real undo, field-value
recovery, audit, and safe offline create/toggle.

## Principle

The **append-only change log is the source of truth.** The existing tables
(`bookings`, `tasks`, …) become a **projection** — a materialized fold of the
log for fast reads. Every mutation:

1. appends an immutable event to `changes`, then
2. applies it to the projection,

in one transaction. Nothing is ever updated-in-place without first being
recorded; nothing is ever physically deleted.

## What this unlocks (vs v1)

| Capability | v1 (soft-delete + LWW) | v2 (change log) |
|---|---|---|
| Recover a deleted row | ✅ (un-tombstone) | ✅ |
| **Recover a previous field value after an edit** | ❌ only last value kept | ✅ full history |
| **Undo an edit (multi-level)** | ❌ | ✅ |
| Audit "what changed, when, which device" | ❌ | ✅ (the log) |
| Offline create / toggle | ❌ (online-only) | ✅ (client UUID + idempotent) |
| Field-level merge | ❌ row-level LWW | ✅ per-field replay |

## Schema (additive)

```sql
CREATE TABLE changes (
    change_id   TEXT PRIMARY KEY,   -- client-generated UUID = idempotency key
    seq         INTEGER,            -- server-assigned monotonic order (AUTOINCREMENT)
    entity      TEXT NOT NULL,      -- 'booking' | 'task' | ...
    entity_id   TEXT NOT NULL,      -- client-generated UUID for creates
    op          TEXT NOT NULL,      -- 'create' | 'update' | 'delete' | 'restore'
    patch       TEXT,               -- JSON: changed fields (+ prior values, for undo)
    device      TEXT,               -- which client made it
    client_ts   TEXT NOT NULL,      -- when the client made the change
    created_at  TEXT NOT NULL       -- when the server recorded it
);
CREATE INDEX idx_changes_seq    ON changes(seq);
CREATE INDEX idx_changes_entity ON changes(entity, entity_id, seq);
```

Projection tables stay as-is (already have `created_at`/`updated_at`/`deleted_at`
from v1). They can always be rebuilt by replaying `changes`.

## Write path

- Client assigns `change_id` (UUID) **and** `entity_id` for creates.
- `POST /changes` accepts one or a batch of events. The server:
  - ignores any `change_id` it already has (**idempotent replay** — safe to
    retry an offline op),
  - assigns `seq`, appends to `changes`, applies to the projection,
  - returns the new high-water `seq`.

## Read path

Unchanged — reads come from the projection tables (fast).

## Sync

- Pull: `GET /changes?since_seq=N` → events with `seq > N`. Client applies them
  to its local projection and advances its cursor. (Replaces the snapshot diff;
  events are naturally ordered and idempotent.)
- Push: the client outbox already holds local events; it POSTs them to
  `/changes`. Because they're keyed by `change_id`, a double-send is harmless.
- Conflict: events apply in `seq` order, field-by-field; `client_ts` breaks ties.
  Single-user, so genuine conflicts are rare — but nothing is silently lost
  because the overwritten value is still in the log.

## Undo / redo

Undo is **append-only too** — never rewrite history:

- To undo a change, append a compensating event that restores the prior field
  values (which are recorded in the change's `patch`). An "undelete" is just a
  `restore` event clearing the tombstone.
- The compensating event is itself in the log, so **redo** is undo-of-the-undo.
- Granularity: per-entity ("undo last change to this booking") is trivial via
  `idx_changes_entity`; a global "undo last action" works off `seq` order.
- Worst case (a value clobbered like the lost car booking): the old value is in
  `patch`, so recovery is a one-event restore — no backups required.

## Migration from v1

1. Add the `changes` table (additive).
2. Route every mutation through append-then-apply.
3. Optional one-time seed: emit a synthetic `create` event per existing row so
   the log is complete from day one.
4. Add client-generated UUIDs/idempotency to all mutations (this also retires
   the v1 "create/toggle are online-only" limitation).
5. Keep v1's projection tables, soft-deletes, and offline outbox — the outbox
   becomes "unsynced change events."

## When NOT to do this

Single-user with a small dataset: the log stays tiny, so cost is low. If this
ever grows multi-user or large, prefer a proven offline-sync engine
(PowerSync / ElectricSQL / libSQL replicas) over hand-rolling conflict logic.
Optional later: log compaction/snapshotting if history gets large.
