#Software Development Engineering Standards & Best Practices

This document establishes foundational architectural guidelines, optimization patterns, and engineering standards for building responsive cross-platform mobile applications, scalable Python backends, robust relational database schemas, and secure Large Language Model (LLM) integrations.

---

## 1. Flutter & Mobile Client Architecture

Modern cross-platform mobile architecture demands high maintainability, seamless rendering performance, and decoupled business logic layers to ensure scalable application lifecycles.

### 1.1 Architectural Pattern: MVVM with Feature-First Organization
For production-grade mobile clients, applications should combine Model-View-ViewModel (MVVM) with a **Feature-First** structure rather than a layer-first design. Code is organized into discrete domain features (e.g., `auth`, `vocabulary`, `profile`, `day_flow`), with each feature split into four distinct, isolated layers:

* **View Layer:** Clean UI declarations using stateless or stateful widgets. Widgets must only display current state and capture user events; they must contain zero business logic or direct database/network queries.
* **ViewModel / State Layer:** Manages the UI state and reacts to user interactions. Utilizing state management solutions like Riverpod (Notifiers) or BLoC allows widgets to selectively listen to distinct data fields, preventing full-screen redraws and optimizing render passes.
* **Repository Layer:** Serves as the single source of truth for a domain feature. It decides whether to fetch cached data from a local database or request live data from an external API or backend service.
* **Service Layer:** Dedicated isolated blocks interacting with outside APIs, local secure storage, hardware configurations, or third-party SDKs.

### 1.2 Performance & UI Optimization
* **Minimize Rebuild Scopes:** Refactor massive widget tree build methods into smaller, standalone `StatelessWidget` classes to restrict the rendering engine's mutation boundaries. Always use the `const` constructor for immutable widgets.
* **Render Engine Alignment:** Leverage the Impeller rendering engine to guarantee predictable 60/120fps animations. Avoid costly runtime graphics operations such as using the `Opacity` widget directly within loops or animations; prefer pre-optimized widgets like `FadeTransition` or `AnimatedOpacity`.
* **Resource Lifecycle Management:** To eliminate memory leaks, explicitly cancel `StreamSubscription` objects and call `.dispose()` on all `TextEditingController`, `AnimationController`, and `ScrollController` instances inside the widget's lifecycle `dispose()` hooks.
* **Off-Thread Heavy Processing:** The main UI thread must remain unblocked to prevent frame drops. Offload CPU-intensive operations (such as parsing large JSON arrays, cryptographic math, or image byte processing) to background worker threads using Dart `Isolates` via the `compute` wrapper function.

---

## 2. Python Backend Server Development

Backend applications built on Python should prioritize structured routing, asynchronous processing safety, strict runtime schema validation, and defensive exception management.

### 2.1 Framework Layout & Layered Architecture
Using modern asynchronous frameworks like FastAPI, applications should maintain a distinct boundary architecture under a structured root directory:


src/
├── main.py                 # Application initialization and global middleware
├── routers/                # HTTP path matching, request parameters, status codes
├── services/               # Core business logic processing and domain validations
├── repositories/           # Database execution, ORM calling, and raw queries
└── models/                 # Pydantic schemas and database entity mappings

### 2.2 Asynchronous Concurrency and Worker Offloading
FastAPI manages synchronous execution blocks by sending them to an internal threadpool, while asynchronous code runs sequentially on the primary event loop. Non-blocking structures must be systematically maintained.

* **Non-Blocking Routing:** If a route is defined with `async def`, only use non-blocking, awaited libraries (e.g., `httpx` for requests, `asyncpg` or async-configured SQLAlchemy for databases). Never use blocking functions like `time.sleep()` inside an async context.
* **Background Task Routing:** Long-running requests must be offloaded from the primary HTTP response cycle. Use the appropriate layer based on operational duration:

| Mechanism | Ideal Task Duration | Target Use Case | Capabilities / Limits |
| :--- | :--- | :--- | :--- |
| **FastAPI BackgroundTasks** | Short (< 1 second) | In-process logging, firing simple confirmation emails. | Runs in the same process; no native retry logic or advanced state visibility. |
| **Distributed Queues (Celery / Arq)** | Seconds to Minutes | CPU-heavy calculations, media optimization, external asset syncing. | Operates via a distinct worker pool; includes dead-letter queues, rate-limiting, and cron scheduling. |

### 2.3 Exception Management & Security
* **Standardized Error Packaging:** Avoid returning arbitrary server string exceptions. Implement global exception handlers that intercept processing failures and format them into clear, structured JSON error envelopes:
  ```json
  {
    "error": "VALIDATION_ERROR",
    "message": "The supplied payload format is invalid.",
    "details": null
  }

•	Input Sanitization: Enforce strict runtime data parsing on inbound payloads through typing libraries like Pydantic. Ensure all authentication layers use secure asymmetric JWT signature verification, robust OAuth2 flows, and strict Role-Based Access Control (RBAC).
3. Relational Database Design
A solid relational database layer relies on strong data integrity, predictable naming patterns, targeted indexing structures, and declarative migration version control.
3.1 Naming and Schema Conventions
•	Case Uniformity: Apply lowercase snake case (lower_case_snake) across all tables, column names, views, and index definitions.
•	Singular Entity Definitions: Use the singular form for table targets (e.g., user, order_item, vocabulary_word) rather than plurals to maintain clear relationship definitions.
•	Standard Suffix Metrics: Append standard designations consistently across tracking attributes: Use _id for primary and foreign key references, and use _at for timestamp parameters (e.g., created_at, updated_at).
3.2 Index Architecture and Query Optimization
•	Target Key Filters: Generate explicit indexes for columns routinely targeted by WHERE conditionals, JOIN constraints, or sorting requirements (ORDER BY and GROUP BY).
•	Composite Index Ordering: When querying across multiple conditions simultaneously, implement composite multi-column indexes. Always place the most selective filter attribute first in the definition array.
•	Prevent Index Over-Saturation: While indexes drastically reduce read latencies, each additional index adds writing overhead during inserts, updates, and deletes. Continuously monitor query logs and index performance tables (e.g., pg_stat_user_indexes in PostgreSQL) to spot and eliminate unused or redundant indexes.
3.3 Schema Version Control and Migrations
Database schemas must never be manually altered in production environment instances. Use structured migration tools like Alembic to manage structural definitions programmatically.
•	Migrations must be fully static, deterministic, and easily reversible (providing clear, balanced upgrade() and downgrade() directions).
•	Use chronological, human-readable file labeling conventions to simplify tracking across multi-developer setups (e.g., YYYY-MM-DD_short_descriptive_slug.py).
4. Client-Server Integration & API Design
Integrating mobile clients with backend services requires highly structured contracts to optimize network reliability, response times, and bandwidth usage over mobile networks.
•	RESTful URL Immutability: Design paths around logical resource grouping hierarchies using predictable lowercase terms. Use plural forms for collections and clear individual IDs for specific resources:
•	GET /api/v1/words (Fetches a collection of vocabulary entries)
•	POST /api/v1/words (Creates a single entry)
•	GET /api/v1/words/{id} (Fetches a specific entry)
•	API Version Isolation: Prefix all API routes with structural version tags (e.g., /api/v1/). This allows you to introduce breaking architectural shifts later via /api/v2/ without breaking legacy mobile application builds actively running on user devices.
•	Mobile-Specific Wire Performance: Native mobile interactions are susceptible to high latency and fluctuating cell coverage. Backends must support pagination (preferring cursor-based sorting for rapidly mutating feeds) and payload stripping to avoid wasting device memory. Compress response payloads using Gzip or Brotli compression before transit.
5. Large Language Model (LLM) & AI Integration Architecture
Integrating foundational models (such as Google Gemini or Anthropic Claude) requires a strict separation of concerns to protect API credentials, manage high latency, and handle the inherent non-deterministic nature of AI outputs.
5.1 Backend Proxying & Security Layer
•	Zero Client-Side Keys: Mobile clients must never make direct HTTP requests to LLM provider endpoints (e.g., Anthropic or Google AI Studio APIs). All AI interactions must be proxied through the secure Python backend server. This protects API keys from reverse-engineering and allows centralized rate-limiting, logging, and cost tracking.
•	Input Sanitization & Injection Mitigation: Treat user-facing text fields destined for an LLM prompt as untrusted input. Implement backend validation layers to detect and strip out prompt injection attempts (e.g., instructions telling the model to "ignore previous rules").
5.2 Structured Outputs & Schema Enforcement
To reliably consume AI data within a Flutter application, avoid requesting raw text or markdown from the model. Force the model to return strictly structured data.
•	Native JSON Schema Mode: Utilize the provider's native structured output capabilities (such as Gemini’s responseSchema or Claude's tool-use/JSON mode).
•	Pydantic Validation: In the Python service layer, pass the incoming LLM JSON payload directly into a Pydantic model. This guarantees that if a model hallucinates an invalid data type or omits a required field, the backend catches the validation error before it propagates to the mobile client.
from pydantic import BaseModel, Field

class VocabularyScene(BaseModel):
    target_word: str
    context_sentence: str
    creative_scenario: str = Field(description="A funny or vivid scene to aid memory retention.")
    visual_cue_prompt: str

5.3 Asynchronous Execution, Streaming, and UX Optimization
LLM generations typically suffer from high Time-to-First-Token (TTFT) and total execution latencies (often ranging from 2 to 7+ seconds).
•	UI State & Loading Indicators: The Flutter view layer must react gracefully to these delays. Utilize localized loading animations or shimmer effects. Never freeze the app UI while waiting for an LLM response thread.
•	Server-Sent Events (SSE) / Streaming: For long-form text generation, configure the Python backend to stream tokens immediately to the mobile app via EventStreams (e.g., sse_starlette in FastAPI) instead of waiting for the full payload to complete. The Flutter client can use a StreamBuilder or a Riverpod StreamProvider to render text in real time, drastically reducing perceived latency.
•	Distributed Task Offloading: If the AI generation triggers secondary slow operations (such as generating an image via Imagen/Midjourney or updating extensive vector databases), offload these entirely to your background worker queue (Celery/Arq), and alert the user via a background sync or push notification when the resources are ready.
5.4 Prompt Engineering Lifecycle and Resiliency
•	Prompts as Code: Store system instructions and base prompt templates inside your backend source control repository, not hardcoded into runtime databases or client code. Version-control them alongside your backend logic.
•	Graceful Degradation & Fallbacks: Build a redundancy matrix into your Python service layer. If your primary model hits a rate limit (HTTP 429) or experiences an outage, the code should catch the exception and immediately failover to a secondary model or provider (e.g., falling back from Claude 3.5 Sonnet to Gemini 1.5 Flash or vice versa).
6. Document Sources & References
The engineering principles compiled in this document are synthesized from established industry benchmarks, architectural white papers, and framework documentation:
•	Flutter Architecture & Performance Guidelines: Derived from the official Flutter Architecture Documentation Guidelines, advocating clean separation of concerns using declarative MVVM boundaries and the implementation of Feature-First directory schemas.
•	FastAPI Production Conventions & Enterprise Design Patterns: Adapted from open-source repository structures, detailing the separation of route controllers from deep domain service operations and safe async event-loop threadpool allocation mechanics.
•	Relational Index Architecture and Design Systems (Microsoft Learn / Postgres Documentation): Sourced from enterprise relational storage engine optimization guides, focusing on composite index attribute prioritization, monitoring structural write overhead, and programmatic schema control.
•	REST API Design Best Practices (Auth0 Core Engineering Guides): Compiled from industry API design handbooks, advocating for URL structural immutability, plural entity resource collections, and client endpoint versioning control.
•	Google AI & Anthropic Developer Production Playbooks: Synthesized from provider-specific best practices for enterprise application deployments, emphasizing backend API proxy security, structured JSON schema enforcement via Pydantic, prompt isolation, and model failover strategies.
