import os
import shutil
import sys
import tempfile
from pathlib import Path

# Ensure the backend dir is on sys.path so `from app.main import app` works
# regardless of where pytest is invoked from.
BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

# Isolate test runs: copy the seed DB to a temp file and point the app at it.
# Must happen BEFORE any `from app...` import so config.DB_PATH picks it up.
_SEED_DB = BACKEND_DIR / "db" / "wayfarer.db"
_TEST_DB = Path(tempfile.gettempdir()) / "wayfarer-test.db"
if _SEED_DB.exists():
    shutil.copy(_SEED_DB, _TEST_DB)
os.environ["DB_PATH"] = str(_TEST_DB)
