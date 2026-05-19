import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()  # backend/.env
load_dotenv(Path(__file__).resolve().parent.parent.parent / ".env")  # project root .env

BACKEND_DIR = Path(__file__).resolve().parent.parent

ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY", "").strip() or None
ANTHROPIC_MODEL = os.getenv("ANTHROPIC_MODEL", "claude-sonnet-4-6").strip()

DB_PATH = os.getenv("DB_PATH", "").strip() or str(BACKEND_DIR / "db" / "wayfarer.db")
MIGRATIONS_DIR = BACKEND_DIR / "db" / "migrations"

_origins_env = os.getenv("CORS_ORIGINS", "*").strip()
CORS_ORIGINS = ["*"] if _origins_env in ("", "*") else [o.strip() for o in _origins_env.split(",") if o.strip()]
