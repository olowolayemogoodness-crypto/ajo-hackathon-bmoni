from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from sqlalchemy import Engine

from app.api.health import router as health_router
from app.core.config import Settings, get_settings
from app.db.session import create_database_engine


def create_app(
    settings: Settings | None = None,
    engine: Engine | None = None,
) -> FastAPI:
    configured_settings = settings or get_settings()
    database_engine = engine or create_database_engine(configured_settings)

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
    app.include_router(health_router)
    return app


app = create_app()