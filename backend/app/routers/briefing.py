import sqlite3
from datetime import date as date_cls
from fastapi import APIRouter, Depends, HTTPException, Response

from ..db import get_db
from ..models import Briefing, BriefingGenerateRequest
from ..repositories.briefing_repository import BriefingRepository
from ..services import briefing as briefing_svc
from ..services import claude as claude_svc

router = APIRouter(prefix="/briefing", tags=["briefing"])


@router.post("/generate", response_model=Briefing)
def generate(payload: BriefingGenerateRequest, db: sqlite3.Connection = Depends(get_db)):
    day = (payload.date or date_cls.today().isoformat())[:10]

    base_md = briefing_svc.generate_briefing(db, day)

    # Optionally rephrase via Claude. If unavailable, fall back to the deterministic markdown.
    try:
        system = (
            "You are Wayfarer's morning briefing writer. Rewrite the provided "
            "draft briefing into concise, friendly markdown that Paul can read "
            "in under 30 seconds. Preserve every concrete fact (booking names, "
            "dates, statuses, task counts). Keep it terse — bullet form. Do "
            "not invent facts."
        )
        rephrased = claude_svc.call_simple(system, base_md, max_tokens=1024)
        markdown = rephrased if rephrased.strip() else base_md
    except claude_svc.ClaudeUnavailableError:
        markdown = base_md
    except Exception:
        markdown = base_md

    row = BriefingRepository(db).upsert(day, markdown)
    return Briefing(**row)


@router.get("/today", response_class=Response)
def today(db: sqlite3.Connection = Depends(get_db)):
    """Return the latest cached briefing as raw markdown."""
    row = BriefingRepository(db).latest()
    if not row:
        raise HTTPException(status_code=404, detail="no briefing has been generated yet")
    return Response(content=row["markdown"], media_type="text/markdown")
