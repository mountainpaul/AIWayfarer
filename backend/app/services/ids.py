"""ID generation.

UUIDv7 (RFC 9562 §5.7) is time-ordered: a 48-bit big-endian Unix-epoch-ms
prefix, then the version/variant bits, then random. Time-ordered IDs keep
B-tree index locality on insert and sort roughly by creation time — handy for
a single-row-per-user table that may grow into per-trip history later.

Only entities that opt in (currently traveler_profile) use this; the rest keep
client- or uuid4-generated ids via BaseRepository.
"""
import os
import time
import uuid


def uuidv7() -> str:
    unix_ms = int(time.time() * 1000)
    b = bytearray(unix_ms.to_bytes(6, "big") + os.urandom(10))
    b[6] = (b[6] & 0x0F) | 0x70  # version 7
    b[8] = (b[8] & 0x3F) | 0x80  # variant 10
    return str(uuid.UUID(bytes=bytes(b)))
