from sqlalchemy import Engine, create_engine
from sqlalchemy.orm import Session
from starlette.requests import Request

from app.core.config import Settings


def create_database_engine(settings: Settings) -> Engine:
    return create_engine(settings.database_url, pool_pre_ping=True)


def get_db_session(request: Request):
    with Session(request.app.state.engine) as session:
        yield session
