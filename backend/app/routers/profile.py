import sqlite3

from fastapi import APIRouter, Depends

from ..db import get_db
from ..models import TravelerProfile, TravelerProfileUpdate
from ..repositories.traveler_profile_repository import TravelerProfileRepository

# Single-user v1: the profile is a singleton keyed by user_id, so there is no
# id in the path. GET auto-creates an empty profile on first access.
router = APIRouter(prefix="/profile", tags=["profile"])


@router.get("", response_model=TravelerProfile)
def get_profile(db: sqlite3.Connection = Depends(get_db)):
    return TravelerProfile(**TravelerProfileRepository(db).ensure())


@router.patch("", response_model=TravelerProfile)
def update_profile(
    payload: TravelerProfileUpdate, db: sqlite3.Connection = Depends(get_db)
):
    patch = payload.model_dump(exclude_unset=True)
    return TravelerProfile(**TravelerProfileRepository(db).update_for_user(patch))
