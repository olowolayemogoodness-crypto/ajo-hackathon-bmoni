import asyncio

import httpx
from sqlalchemy import create_engine

from app.core.config import Settings
from app.main import create_app


def request(app, path: str) -> httpx.Response:
    async def send_request() -> httpx.Response:
        transport = httpx.ASGITransport(app=app)
        async with httpx.AsyncClient(
            transport=transport,
            base_url="http://test",
        ) as client:
            return await client.get(path)

    return asyncio.run(send_request())


def test_health_is_liveness_only() -> None:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    app = create_app(
        settings=Settings(database_url="sqlite+pysqlite:///:memory:"),
        engine=engine,
    )

    response = request(app, "/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
    engine.dispose()


def test_ready_checks_database_connection() -> None:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    app = create_app(
        settings=Settings(database_url="sqlite+pysqlite:///:memory:"),
        engine=engine,
    )

    response = request(app, "/ready")

    assert response.status_code == 200
    assert response.json() == {"status": "ready"}
    engine.dispose()
