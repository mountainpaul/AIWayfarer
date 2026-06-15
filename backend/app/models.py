from typing import Literal, Optional
from pydantic import BaseModel, ConfigDict, Field

# ── Enums (string literals matching the schema) ─────────────────

BookingType = Literal["flight", "hotel", "ferry", "car", "train", "activity", "rifugio", "other"]
BookingStatus = Literal["booked", "pending", "needs_booking", "researching"]
TaskPriority = Literal["critical", "high", "medium", "low"]
PackingCategory = Literal["clothing", "layers", "footwear", "toiletries", "electronics", "documents", "gear", "misc"]
JournalEntryType = Literal["note", "voice", "reflection"]
ChatMode = Literal["planning", "companion"]
Confidence = Literal["high", "medium", "low"]
TripStatus = Literal["planning", "active", "completed"]


# ── Trip ────────────────────────────────────────────────────────

class Trip(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    name: str
    start_date: str
    end_date: str
    status: TripStatus = "planning"
    created_at: str
    updated_at: str
    deleted_at: Optional[str] = None


class TripCreate(BaseModel):
    name: str
    start_date: str
    end_date: str
    status: TripStatus = "planning"


class TripUpdate(BaseModel):
    name: Optional[str] = None
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    status: Optional[TripStatus] = None


# ── Leg ─────────────────────────────────────────────────────────

class Leg(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    trip_id: str
    slug: str
    name: str
    emoji: Optional[str] = None
    color: Optional[str] = None
    start_date: str
    end_date: str
    is_schengen: bool
    budget_cents: Optional[int] = None
    currency: str = "USD"
    places: Optional[str] = None
    notes: Optional[str] = None
    sort_order: int
    created_at: str
    updated_at: str
    deleted_at: Optional[str] = None


class LegCreate(BaseModel):
    trip_id: str
    slug: str
    name: str
    emoji: Optional[str] = None
    color: Optional[str] = None
    start_date: str
    end_date: str
    is_schengen: bool = False
    budget_cents: Optional[int] = None
    currency: str = "USD"
    places: Optional[str] = None
    notes: Optional[str] = None
    sort_order: int = 0


class LegUpdate(BaseModel):
    name: Optional[str] = None
    emoji: Optional[str] = None
    color: Optional[str] = None
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    is_schengen: Optional[bool] = None
    budget_cents: Optional[int] = None
    currency: Optional[str] = None
    places: Optional[str] = None
    notes: Optional[str] = None
    sort_order: Optional[int] = None


# ── Booking ─────────────────────────────────────────────────────

class Booking(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    leg_id: str
    type: BookingType
    name: str
    status: BookingStatus
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    confirmation: Optional[str] = None
    cost_cents: Optional[int] = None
    currency: str = "USD"
    location_name: Optional[str] = None
    location_lat: Optional[float] = None
    location_lon: Optional[float] = None
    notes: Optional[str] = None
    created_at: str
    updated_at: str
    deleted_at: Optional[str] = None


class BookingCreate(BaseModel):
    leg_id: str
    type: BookingType
    name: str
    status: BookingStatus = "researching"
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    confirmation: Optional[str] = None
    cost_cents: Optional[int] = None
    currency: str = "USD"
    location_name: Optional[str] = None
    location_lat: Optional[float] = None
    location_lon: Optional[float] = None
    notes: Optional[str] = None


class BookingUpdate(BaseModel):
    leg_id: Optional[str] = None
    type: Optional[BookingType] = None
    name: Optional[str] = None
    status: Optional[BookingStatus] = None
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    confirmation: Optional[str] = None
    cost_cents: Optional[int] = None
    currency: Optional[str] = None
    location_name: Optional[str] = None
    location_lat: Optional[float] = None
    location_lon: Optional[float] = None
    notes: Optional[str] = None


# ── Task ────────────────────────────────────────────────────────

class Task(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    leg_id: Optional[str] = None
    title: str
    priority: TaskPriority
    due_date: Optional[str] = None
    is_done: bool
    notes: Optional[str] = None
    created_at: str
    updated_at: str
    deleted_at: Optional[str] = None


class TaskCreate(BaseModel):
    leg_id: Optional[str] = None
    title: str
    priority: TaskPriority = "medium"
    due_date: Optional[str] = None
    is_done: bool = False
    notes: Optional[str] = None


class TaskUpdate(BaseModel):
    leg_id: Optional[str] = None
    title: Optional[str] = None
    priority: Optional[TaskPriority] = None
    due_date: Optional[str] = None
    is_done: Optional[bool] = None
    notes: Optional[str] = None


# ── Packing Item ────────────────────────────────────────────────

class PackingItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    trip_id: str
    category: PackingCategory
    name: str
    is_packed: bool
    sort_order: int
    created_at: str
    updated_at: str
    deleted_at: Optional[str] = None


class PackingItemCreate(BaseModel):
    trip_id: str
    category: PackingCategory
    name: str
    is_packed: bool = False
    sort_order: int = 0


class PackingItemUpdate(BaseModel):
    category: Optional[PackingCategory] = None
    name: Optional[str] = None
    is_packed: Optional[bool] = None
    sort_order: Optional[int] = None


# ── Journal Entry ───────────────────────────────────────────────

class JournalEntry(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    leg_id: Optional[str] = None
    content: str
    entry_type: JournalEntryType
    location_name: Optional[str] = None
    location_lat: Optional[float] = None
    location_lon: Optional[float] = None
    created_at: str
    updated_at: Optional[str] = None
    deleted_at: Optional[str] = None


class JournalEntryCreate(BaseModel):
    leg_id: Optional[str] = None
    content: str
    entry_type: JournalEntryType = "note"
    location_name: Optional[str] = None
    location_lat: Optional[float] = None
    location_lon: Optional[float] = None


# ── Traveler Profile ────────────────────────────────────────────

class TravelerProfile(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    user_id: str
    # Permanent typed columns (standardized string tokens; values illustrative,
    # not yet constrained — kept flexible while the questionnaire stabilizes).
    lodging_style: Optional[str] = None        # boutique | luxury | budget_guesthouse | ...
    transport_preference: Optional[str] = None  # rental_car | public_transit | trains | ...
    travel_pace: Optional[str] = None           # relaxed | moderate | packed
    budget_tier: Optional[str] = None           # economy | mid_range | splurge
    # Distilled AI paragraph injected into the chat grounding layer.
    profile_summary: Optional[str] = None
    # JSON sandbox for evolving questionnaire fields, tags, and avoids.
    preferences_blob: dict = Field(default_factory=dict)
    created_at: str
    updated_at: str
    deleted_at: Optional[str] = None


class TravelerProfileUpdate(BaseModel):
    lodging_style: Optional[str] = None
    transport_preference: Optional[str] = None
    travel_pace: Optional[str] = None
    budget_tier: Optional[str] = None
    profile_summary: Optional[str] = None
    # When provided, replaces the blob wholesale (merge semantics can come later).
    preferences_blob: Optional[dict] = None


# ── Grounding ───────────────────────────────────────────────────

class GPS(BaseModel):
    lat: float
    lon: float


class GroundingPayload(BaseModel):
    """Accept the grounding shape sent by the Flutter app."""
    gps_lat: Optional[float] = None
    gps_lon: Optional[float] = None
    gps_accuracy_m: Optional[float] = None
    local_time_iso: str
    timezone: Optional[str] = None
    current_leg_id: Optional[str] = None
    current_leg_slug: Optional[str] = None
    current_trip_id: Optional[str] = None
    next_booking_id: Optional[str] = None


# ── Chat ────────────────────────────────────────────────────────

class ChatRequest(BaseModel):
    message: str
    grounding: Optional[GroundingPayload] = None
    mode: ChatMode = "companion"
    session_id: Optional[str] = None


class ChatResponse(BaseModel):
    answer: str
    draft: str
    critique: str
    confidence: Confidence
    sources: list[str] = Field(default_factory=list)
    iterations: list[dict] = Field(default_factory=list)


# ── Briefing ────────────────────────────────────────────────────

class Briefing(BaseModel):
    id: str
    date: str
    markdown: str
    created_at: str
    updated_at: Optional[str] = None
    deleted_at: Optional[str] = None


class BriefingGenerateRequest(BaseModel):
    date: Optional[str] = None  # ISO date; defaults to "today" in caller's local sense


# ── Budget rollup ───────────────────────────────────────────────

class BudgetLine(BaseModel):
    currency: str
    planned_cents: int
    actual_cents: int
    remaining_cents: int


class BudgetReport(BaseModel):
    by_currency: list[BudgetLine] = Field(default_factory=list)


# ── Accommodation coverage ──────────────────────────────────────

class CoverageItem(BaseModel):
    leg_id: str
    leg_name: str
    start_date: str
    end_date: str
    total_nights: int
    booked_nights: int
    unbooked_nights: int


# ── Schengen 90/180 tracker ─────────────────────────────────────

class SchengenReport(BaseModel):
    as_of: str
    window_days: int
    limit_days: int
    days_used: int
    days_remaining: int
    status: Literal["ok", "warning", "exceeded"]
    peak_days: int
    peak_date: Optional[str] = None
    ever_exceeds: bool


# ── Sync snapshot ───────────────────────────────────────────────

class SyncSnapshot(BaseModel):
    generated_at: str
    # Cursor the client stores and passes back as ?since= for the next delta sync.
    server_time: str
    # True when this is a delta (since= was provided): rows are only those changed
    # after the cursor, and tombstoned rows may be present (deleted_at set).
    is_delta: bool = False
    current_leg: Optional[Leg] = None
    trips: list[Trip] = Field(default_factory=list)
    legs: list[Leg] = Field(default_factory=list)
    bookings: list[Booking] = Field(default_factory=list)
    tasks: list[Task] = Field(default_factory=list)
    packing_items: list[PackingItem] = Field(default_factory=list)
    journal_entries: list[JournalEntry] = Field(default_factory=list)
