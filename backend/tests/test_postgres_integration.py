import asyncio
import os
from pathlib import Path

import httpx
import pytest
from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, inspect, select
from sqlalchemy.engine import make_url
from sqlalchemy.orm import Session

from app.auth.identity import VerifiedIdentity
from app.core.config import get_settings
from app.main import create_app
from app.modules.users.models import User

POSTGRES_URL = os.environ.get("AJO_TEST_POSTGRES_URL")


class FixedVerifier:
    def verify(self, token: str) -> VerifiedIdentity:
        assert token == "postgres-integration-token"
        return VerifiedIdentity("postgres-concurrent-uid", "Integration User")


@pytest.mark.postgres
@pytest.mark.skipif(
    not POSTGRES_URL, reason="set AJO_TEST_POSTGRES_URL to a disposable *_test database"
)
def test_postgres_migration_and_concurrent_first_session_requests(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    database_url = make_url(POSTGRES_URL)
    if not database_url.database or not database_url.database.endswith("_test"):
        pytest.fail("AJO_TEST_POSTGRES_URL database name must end in _test")

    engine = create_engine(database_url)
    try:
        existing_tables = set(inspect(engine).get_table_names()) - {"alembic_version", "users"}
        if existing_tables:
            pytest.fail(
                f"Expected a dedicated test database; found other tables: {existing_tables}"
            )

        monkeypatch.setenv("AJO_DATABASE_URL", str(database_url))
        get_settings.cache_clear()
        backend_root = Path(__file__).resolve().parents[1]
        alembic_config = Config(str(backend_root / "alembic.ini"))
        alembic_config.set_main_option("script_location", str(backend_root / "migrations"))
        command.upgrade(alembic_config, "head")
        assert {"users", "alembic_version"}.issubset(inspect(engine).get_table_names())

        app = create_app(engine=engine, identity_verifier=FixedVerifier())

        async def send_session() -> httpx.Response:
            transport = httpx.ASGITransport(app=app)
            async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
                return await client.post(
                    "/v1/session",
                    headers={"Authorization": "Bearer postgres-integration-token"},
                )

        async def send_concurrent_sessions() -> list[httpx.Response]:
            return await asyncio.gather(*(send_session() for _ in range(12)))

        responses = asyncio.run(send_concurrent_sessions())

        assert all(response.status_code == 200 for response in responses)
        assert len({response.json()["user"]["id"] for response in responses}) == 1
        with Session(engine) as session:
            users = session.scalars(
                select(User).where(User.firebase_uid == "postgres-concurrent-uid")
            ).all()
        assert len(users) == 1
    finally:
        engine.dispose()
        get_settings.cache_clear()
