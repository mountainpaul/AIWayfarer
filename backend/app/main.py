from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from . import config
from .db import apply_migrations
from .routers import (
    bookings,
    briefing,
    calendar,
    chat,
    gmail,
    grounding,
    journal,
    legs,
    packing,
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

    app.include_router(trips.router)
    app.include_router(legs.router)
    app.include_router(bookings.router)
    app.include_router(tasks.router)
    app.include_router(packing.router)
    app.include_router(journal.router)
    app.include_router(chat.router)
    app.include_router(briefing.router)
    app.include_router(grounding.router)
    app.include_router(sync.router)
    app.include_router(calendar.router)
    app.include_router(gmail.router)

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
