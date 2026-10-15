import asyncio

import httpx
import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.auth.authorization import require_circle_role
from app.auth.identity import InvalidFirebaseToken, VerifiedIdentity
from app.core.config import Settings
from app.db.base import Base
from app.main import create_app
from app.modules.circles.models import Circle, Membership
from app.modules.users.models import User


class FakeVerifier:
    def __init__(self, identities: dict[str, VerifiedIdentity]) -> None:
        self._identities = identities

    def verify(self, token: str) -> VerifiedIdentity:
        if token not in self._identities:
            raise InvalidFirebaseToken
        return self._identities[token]


def make_app(identities: dict[str, VerifiedIdentity]):
    engine = create_engine(
        "sqlite+pysqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    app = create_app(
        settings=Settings(database_url="sqlite+pysqlite://"),
        engine=engine,
        identity_verifier=FakeVerifier(identities),
    )
    return app, engine


def request(app, method: str, path: str, token: str) -> httpx.Response:
    async def send_request() -> httpx.Response:
        transport = httpx.ASGITransport(app=app)
        async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
            return await client.request(
                method,
                path,
                headers={"Authorization": f"Bearer {token}"},
            )

    return asyncio.run(send_request())


def add_user_circle_membership(
    engine,
    *,
    firebase_uid: str,
    circle_name: str,
    role: str = "member",
    membership_status: str = "active",
) -> tuple[str, str]:
    with Session(engine) as session:
        user = User(firebase_uid=firebase_uid, display_name=firebase_uid)
        circle = Circle(name=circle_name)
        session.add_all([user, circle])
        session.flush()
        membership = Membership(
            user_id=user.id,
            circle_id=circle.id,
            role=role,
            status=membership_status,
        )
        session.add(membership)
        session.commit()
        return user.id, circle.id


def test_active_member_can_read_only_their_circle() -> None:
    identity = VerifiedIdentity("uid-member", "Member")
    app, engine = make_app({"member-token": identity})
    _, allowed_circle_id = add_user_circle_membership(
        engine,
        firebase_uid=identity.firebase_uid,
        circle_name="Allowed Circle",
    )
    other_circle_id = add_user_circle_membership(
        engine,
        firebase_uid="uid-other",
        circle_name="Other Circle",
    )[1]

    allowed = request(app, "GET", f"/v1/circles/{allowed_circle_id}", "member-token")
    denied = request(app, "GET", f"/v1/circles/{other_circle_id}", "member-token")
    session = request(app, "POST", "/v1/session", "member-token")

    assert allowed.status_code == 200
    assert allowed.json() == {"id": allowed_circle_id, "name": "Allowed Circle"}
    assert denied.status_code == 404
    assert session.json()["memberships"] == [
        {
            "circleId": allowed_circle_id,
            "circleName": "Allowed Circle",
            "role": "member",
        }
    ]
    engine.dispose()


@pytest.mark.parametrize("membership_status", ["inactive", "revoked"])
def test_inactive_or_revoked_membership_cannot_read_circle(membership_status: str) -> None:
    identity = VerifiedIdentity(f"uid-{membership_status}", "Member")
    app, engine = make_app({"member-token": identity})
    circle_id = add_user_circle_membership(
        engine,
        firebase_uid=identity.firebase_uid,
        circle_name="Unavailable Circle",
        membership_status=membership_status,
    )[1]

    response = request(app, "GET", f"/v1/circles/{circle_id}", "member-token")

    assert response.status_code == 404
    engine.dispose()


def test_circle_role_guard_denies_member_and_allows_organizer() -> None:
    engine = create_engine("sqlite+pysqlite://", poolclass=StaticPool)
    Base.metadata.create_all(engine)
    member_user_id, member_circle_id = add_user_circle_membership(
        engine,
        firebase_uid="uid-member",
        circle_name="Member Circle",
    )
    organizer_user_id, organizer_circle_id = add_user_circle_membership(
        engine,
        firebase_uid="uid-organizer",
        circle_name="Organizer Circle",
        role="organizer",
    )

    with Session(engine) as session:
        with pytest.raises(HTTPException) as denied:
            require_circle_role(session, member_user_id, member_circle_id, "organizer")
        assert denied.value.status_code == 403
        membership = require_circle_role(
            session,
            organizer_user_id,
            organizer_circle_id,
            "organizer",
        )
        assert membership.role == "organizer"
    engine.dispose()


def test_database_rejects_duplicate_membership_and_unknown_role() -> None:
    engine = create_engine("sqlite+pysqlite://", poolclass=StaticPool)
    Base.metadata.create_all(engine)
    user_id, circle_id = add_user_circle_membership(
        engine,
        firebase_uid="uid-unique",
        circle_name="Unique Circle",
    )

    with Session(engine) as session:
        session.add(
            Membership(user_id=user_id, circle_id=circle_id, role="member", status="active")
        )
        with pytest.raises(IntegrityError):
            session.commit()
        session.rollback()
        session.add(Membership(user_id=user_id, circle_id=circle_id, role="owner", status="active"))
        with pytest.raises(IntegrityError):
            session.commit()
    engine.dispose()
