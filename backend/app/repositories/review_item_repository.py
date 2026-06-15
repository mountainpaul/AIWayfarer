from .base import BaseRepository


class ReviewItemRepository(BaseRepository):
    table = "review_item"
    entity = "review_item"
    default_order = "created_at ASC"

    def for_review(self, review_id: str) -> list[dict]:
        return self.list(filters={"review_id": review_id}, order_by=self.default_order)
