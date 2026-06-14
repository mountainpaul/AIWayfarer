import os
import subprocess
import sys
import tempfile
from pathlib import Path

# Ensure the backend dir is on sys.path so `from app.main import app` works
# regardless of where pytest is invoked from.
BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

# Build a pristine, isolated seed DB for the test session via the v3 migrator.
# Remove the DB AND its WAL/SHM sidecars first — unlinking only the main file
# lets stale state (e.g. old-schema tables) survive a rebuild and pollute tests.
# Must happen BEFORE any `from app...` import so config.DB_PATH picks it up.
_MIGRATE = BACKEND_DIR / "db" / "migrate_trip_hq_v3.py"
_TEST_DB = Path(tempfile.gettempdir()) / "wayfarer-test.db"
for _suffix in ("", "-wal", "-shm"):
    Path(str(_TEST_DB) + _suffix).unlink(missing_ok=True)
subprocess.run(
    [sys.executable, str(_MIGRATE), "--db", str(_TEST_DB)],
    check=True,
    capture_output=True,
)
os.environ["DB_PATH"] = str(_TEST_DB)
