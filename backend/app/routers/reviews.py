import sqlite3

from fastapi import APIRouter, Depends, HTTPException

from ..db import get_db
from ..models import TripReview, TripReviewCreate
from ..repositories.review_item_repository import ReviewItemRepository
from ..repositories.trip_review_repository import TripReviewRepository
from ..services import distill as distill_svc

router = APIRouter(prefix="/reviews", tags=["reviews"])


def _assemble(db: sqlite3.Connection, review_row: dict) -> TripReview:
    items = ReviewItemRepository(db).for_review(review_row["id"])
    return TripReview(**review_row, items=items)


@router.get("", response_model=list[TripReview])
def list_reviews(db: sqlite3.Connection = Depends(get_db)):
    repo = TripReviewRepository(db)
    return [_assemble(db, r) for r in repo.list(order_by=repo.default_order)]


@router.get("/{trip_id}", response_model=TripReview)
def get_review(trip_id: str, db: sqlite3.Connection = Depends(get_db)):
    row = TripReviewRepository(db).by_trip(trip_id)
    if row is None:
        raise HTTPException(status_code=404, detail="no review for this trip")
    return _assemble(db, row)


@router.post("", response_model=TripReview, status_code=201)
def create_review(payload: TripReviewCreate, db: sqlite3.Connection = Depends(get_db)):
    reviews = TripReviewRepository(db)
    if reviews.by_trip(payload.trip_id) is not None:
        raise HTTPException(status_code=409, detail="trip already reviewed")

    review = reviews.create(payload.model_dump(exclude={"items"}))
    item_repo = ReviewItemRepository(db)
    for it in payload.items:
        item_repo.create({**it.model_dump(), "review_id": review["id"]})
    items = item_repo.for_review(review["id"])

    # Fold the review into the traveler profile's distilled summary, which the
    # chat grounding layer injects. Best-effort: a Claude outage must not fail
    # the submission (the structured review is already saved).
    distill_svc.distill_from_review(db, review, items)

    return _assemble(db, review)
