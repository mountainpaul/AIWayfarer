"""Global exception handlers returning a standardized JSON error envelope
(BEST_PRACTICES.md §2.3):

    { "error": "NOT_FOUND", "message": "...", "details": null }
"""
from fastapi import FastAPI
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

_SLUG_BY_STATUS = {
    400: "BAD_REQUEST",
    401: "UNAUTHORIZED",
    403: "FORBIDDEN",
    404: "NOT_FOUND",
    409: "CONFLICT",
    422: "VALIDATION_ERROR",
    429: "RATE_LIMITED",
    500: "INTERNAL_ERROR",
    502: "UPSTREAM_ERROR",
    503: "SERVICE_UNAVAILABLE",
}


def _envelope(status: int, error: str, message: str, details=None) -> JSONResponse:
    return JSONResponse(
        status_code=status,
        content={"error": error, "message": message, "details": details},
    )


def register_error_handlers(app: FastAPI) -> None:
    @app.exception_handler(RequestValidationError)
    async def _on_validation(_request, exc: RequestValidationError):
        return _envelope(
            422,
            "VALIDATION_ERROR",
            "The supplied payload format is invalid.",
            jsonable_encoder(exc.errors()),
        )

    @app.exception_handler(StarletteHTTPException)
    async def _on_http(_request, exc: StarletteHTTPException):
        # detail is usually a human string; structured detail rides in `details`.
        message = exc.detail if isinstance(exc.detail, str) else "Request failed."
        details = None if isinstance(exc.detail, str) else jsonable_encoder(exc.detail)
        return _envelope(
            exc.status_code,
            _SLUG_BY_STATUS.get(exc.status_code, "ERROR"),
            message,
            details,
        )

    @app.exception_handler(Exception)
    async def _on_unhandled(_request, exc: Exception):
        return _envelope(500, "INTERNAL_ERROR", "An unexpected error occurred.")
