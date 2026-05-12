from fastapi import APIRouter

router = APIRouter(prefix="/gmail", tags=["gmail"])


@router.get("/threads")
def list_threads():
    """
    TODO: Google OAuth integration.

    v0.5 scope (spec §5, §10): read-only Gmail access for booking
    confirmations and tickets. Returns [] for now; the real implementation
    will use the same OAuth credentials as the Calendar integration.
    """
    return []
