from fastapi import APIRouter, FastAPI
from fastapi.middleware.cors import CORSMiddleware

from . import config
from .db import apply_migrations
from .errors import register_error_handlers
from .routers import (
    bookings,
    briefing,
    calendar,
    changes,
    chat,
    gmail,
    grounding,
    journal,
    legs,
    packing,
    schengen,
    sync,
    tasks,
    trips,
)


def create_app() -> FastAPI:
    apply_migrations()

    app = FastAPI(
        title="Wayfarer API",
        version="0.5.0",
        description="Travel planning + on-trip companion (single-user, Paul Egges)",
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=config.CORS_ORIGINS,
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    register_error_handlers(app)

    # All resource routes are versioned under /api/v1 (BEST_PRACTICES.md §4) so
    # future breaking changes can ship as /api/v2 without breaking live clients.
    api_v1 = APIRouter(prefix="/api/v1")
    for r in (
        trips.router,
        legs.router,
        bookings.router,
        tasks.router,
        packing.router,
        journal.router,
        chat.router,
        briefing.router,
        grounding.router,
        sync.router,
        changes.router,
        schengen.router,
        calendar.router,
        gmail.router,
    ):
        api_v1.include_router(r)
    app.include_router(api_v1)

    # /health stays unversioned — it's an ops/liveness probe, not a resource.
    @app.get("/health", tags=["meta"])
    def health():
        return {
            "status": "ok",
            "version": "0.5.0",
            "anthropic_configured": bool(config.ANTHROPIC_API_KEY),
            "model": config.ANTHROPIC_MODEL,
        }

    return app


app = create_app()
