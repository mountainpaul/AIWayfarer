import sqlite3
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException

from ..db import get_db
from ..models import ChatRequest, ChatResponse
from ..services import claude as claude_svc
from ..services import critic as critic_svc
from ..services import grounding as grounding_svc

router = APIRouter(prefix="/chat", tags=["chat"])


@router.post("", response_model=ChatResponse)
def chat(payload: ChatRequest, db: sqlite3.Connection = Depends(get_db)):
    if not payload.message.strip():
        raise HTTPException(status_code=400, detail="message is required")

    # Use the supplied grounding payload if present; otherwise derive one from the DB.
    if payload.grounding is not None:
        grounding = payload.grounding
    else:
        grounding = grounding_svc.build_grounding_context(db)

    grounding_text = grounding_svc.grounding_to_text(grounding, db=db)
    profile_summary = grounding_svc.traveler_profile_summary(db)
    system_prompt = critic_svc.build_system_prompt(
        grounding_text, payload.mode, profile_summary=profile_summary
    )

    try:
        raw = claude_svc.call_chat(system_prompt, payload.message)
    except claude_svc.ClaudeUnavailableError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Anthropic API error: {e}")

    return claude_svc.parse_chat_response(raw)
