from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from uuid import uuid4

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from sqlalchemy import Engine
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.api.health import router as health_router
from app.api.session import router as session_router
from app.auth.identity import FirebaseIdentityVerifier, IdentityVerifier
from app.core.config import Settings, get_settings
from app.db.session import create_database_engine


def create_app(
    settings: Settings | None = None,
    engine: Engine | None = None,
    identity_verifier: IdentityVerifier | None = None,
) -> FastAPI:
    configured_settings = settings or get_settings()
    database_engine = engine or create_database_engine(configured_settings)
    verifier = identity_verifier or FirebaseIdentityVerifier(
        configured_settings.firebase_project_id
    )

    @asynccontextmanager
    async def lifespan(_: FastAPI) -> AsyncIterator[None]:
        yield
        database_engine.dispose()

    app = FastAPI(
        title="Ajo API",
        version="1.0.0",
        lifespan=lifespan,
    )
    app.state.settings = configured_settings
    app.state.engine = database_engine
    app.state.identity_verifier = verifier

    @app.middleware("http")
    async def add_request_id(request: Request, call_next):
        request_id = str(uuid4())
        request.state.request_id = request_id
        response = await call_next(request)
        response.headers["X-Request-ID"] = request_id
        return response

    @app.exception_handler(StarletteHTTPException)
    async def http_error(request: Request, exc: StarletteHTTPException) -> JSONResponse:
        status_codes = {
            401: "unauthenticated",
            403: "forbidden",
            404: "not_found",
            409: "state_conflict",
            503: "temporarily_unavailable",
        }
        messages = {
            401: "Authentication is required or the token is invalid.",
            403: "The authenticated user is not permitted to perform this action.",
            404: "The requested resource was not found.",
            409: "The request conflicts with the current resource state.",
            503: "A required service is temporarily unavailable.",
        }
        return JSONResponse(
            status_code=exc.status_code,
            content={
                "error": {
                    "code": status_codes.get(exc.status_code, "request_failed"),
                    "message": messages.get(exc.status_code, "The request could not be completed."),
                    "details": {},
                    "requestId": request.state.request_id,
                }
            },
            headers=exc.headers,
        )

    @app.exception_handler(RequestValidationError)
    async def validation_error(request: Request, _: RequestValidationError) -> JSONResponse:
        return JSONResponse(
            status_code=422,
            content={
                "error": {
                    "code": "invalid_request",
                    "message": "Request validation failed.",
                    "details": {},
                    "requestId": request.state.request_id,
                }
            },
        )

    app.include_router(health_router)
    app.include_router(session_router)
    return app


app = create_app()
