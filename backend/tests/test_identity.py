import asyncio

import firebase_admin
import httpx
import pytest
from alembic import command
from alembic.config import Config
from firebase_admin import auth
from sqlalchemy import create_engine, inspect, select
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.auth.identity import (
    FirebaseIdentityVerifier,
    IdentityProviderUnavailable,
    InvalidFirebaseToken,
    VerifiedIdentity,
)
from app.core.config import Settings, get_settings
from app.db.base import Base
from app.main import create_app
from app.modules.users.models import User


class FakeVerifier:
    def __init__(self, identities: dict[str, VerifiedIdentity]) -> None:
        self._identities = identities

    def verify(self, token: str) -> VerifiedIdentity:
        if token == "unavailable":
            raise IdentityProviderUnavailable("internal credential diagnostics")
        identity = self._identities.get(token)
        if identity is None:
            raise InvalidFirebaseToken
        return identity


def make_app(verifier: FakeVerifier):
    engine = create_engine(
        "sqlite+pysqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    app = create_app(
        settings=Settings(database_url="sqlite+pysqlite://"),
        engine=engine,
        identity_verifier=verifier,
    )
    return app, engine


def post_session(app, authorization: str | None = None) -> httpx.Response:
    async def send_request() -> httpx.Response:
        transport = httpx.ASGITransport(app=app)
        async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
            headers = {"Authorization": authorization} if authorization else {}
            return await client.post("/v1/session", headers=headers)

    return asyncio.run(send_request())


def test_session_requires_valid_bearer_token() -> None:
    app, engine = make_app(FakeVerifier({}))

    response = post_session(app)

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "unauthenticated"
    assert response.headers["X-Request-ID"] == response.json()["error"]["requestId"]
    engine.dispose()


def test_session_resolves_internal_user_without_exposing_firebase_uid() -> None:
    identity = VerifiedIdentity(firebase_uid="firebase-uid-1", display_name="Tolu Adebayo")
    app, engine = make_app(FakeVerifier({"valid-token": identity}))

    first = post_session(app, "Bearer valid-token")
    second = post_session(app, "Bearer valid-token")

    assert first.status_code == 200
    assert first.json()["user"]["displayName"] == "Tolu Adebayo"
    assert first.json()["user"]["id"] == second.json()["user"]["id"]
    assert first.json()["memberships"] == []
    assert "firebase-uid-1" not in first.text
    with Session(engine) as session:
        assert len(session.scalars(select(User)).all()) == 1
    engine.dispose()


def test_session_rejects_invalid_token_and_surfaces_provider_outage_safely() -> None:
    app, engine = make_app(FakeVerifier({}))

    invalid = post_session(app, "Bearer invalid-token")
    unavailable = post_session(app, "Bearer unavailable")

    assert invalid.status_code == 401
    assert unavailable.status_code == 503
    assert unavailable.json()["error"]["code"] == "temporarily_unavailable"
    assert "internal credential diagnostics" not in unavailable.text
    assert "IdentityProviderUnavailable" not in unavailable.text
    engine.dispose()


def test_session_returns_safe_service_error_when_database_is_unavailable() -> None:
    identity = VerifiedIdentity(firebase_uid="firebase-uid-db", display_name=None)
    app, engine = make_app(FakeVerifier({"valid-token": identity}))
    Base.metadata.drop_all(engine)

    response = post_session(app, "Bearer valid-token")

    assert response.status_code == 503
    assert response.json()["error"]["code"] == "temporarily_unavailable"
    assert "sqlalchemy" not in response.text.lower()
    engine.dispose()


def test_firebase_verifier_checks_revocation_and_project_app(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    app_marker = object()
    calls: dict[str, object] = {}

    monkeypatch.setattr(firebase_admin, "get_app", lambda name: app_marker)

    def verify_id_token(token: str, *, app, check_revoked: bool):
        calls.update(token=token, app=app, check_revoked=check_revoked)
        return {"uid": "firebase-uid-2", "name": "Aisha Bello"}

    monkeypatch.setattr(auth, "verify_id_token", verify_id_token)
    identity = FirebaseIdentityVerifier("ajo-hackathon").verify("firebase-token")

    assert identity == VerifiedIdentity("firebase-uid-2", "Aisha Bello")
    assert calls == {"token": "firebase-token", "app": app_marker, "check_revoked": True}


@pytest.mark.parametrize(
    "token_error",
    [
        auth.InvalidIdTokenError,
        auth.ExpiredIdTokenError,
        auth.RevokedIdTokenError,
        auth.UserDisabledError,
        auth.UserNotFoundError,
    ],
)
def test_firebase_verifier_rejects_invalid_expired_revoked_and_disabled_tokens(
    monkeypatch: pytest.MonkeyPatch,
    token_error: type[Exception],
) -> None:
    monkeypatch.setattr(firebase_admin, "get_app", lambda name: object())

    def reject_token(token: str, *, app, check_revoked: bool):
        if token_error is auth.ExpiredIdTokenError:
            raise token_error("rejected token", ValueError("expired"))
        raise token_error("rejected token")

    monkeypatch.setattr(auth, "verify_id_token", reject_token)

    with pytest.raises(InvalidFirebaseToken):
        FirebaseIdentityVerifier("ajo-hackathon").verify("invalid-token")


def test_alembic_migration_creates_internal_users_table(
    tmp_path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    database_url = f"sqlite+pysqlite:///{tmp_path / 'identity.db'}"
    monkeypatch.setenv("AJO_DATABASE_URL", database_url)
    get_settings.cache_clear()
    backend_root = __import__("pathlib").Path(__file__).resolve().parents[1]
    alembic_config = Config(str(backend_root / "alembic.ini"))
    alembic_config.set_main_option("script_location", str(backend_root / "migrations"))

    command.upgrade(alembic_config, "head")
    engine = create_engine(database_url)
    try:
        assert "users" in inspect(engine).get_table_names()
        assert "circles" in inspect(engine).get_table_names()
        assert "memberships" in inspect(engine).get_table_names()
        assert "alembic_version" in inspect(engine).get_table_names()
    finally:
        engine.dispose()
        get_settings.cache_clear()
