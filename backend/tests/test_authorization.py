import asyncio

import httpx
import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine, select, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.auth.authorization import require_circle_role
from app.auth.identity import InvalidFirebaseToken, VerifiedIdentity
from app.core.config import Settings
from app.db.base import Base
from app.main import create_app
from app.modules.circles.models import Circle, Membership, MembershipEvent
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


def request(
    app,
    method: str,
    path: str,
    token: str | None = None,
    body: dict | None = None,
) -> httpx.Response:
    async def send_request() -> httpx.Response:
        transport = httpx.ASGITransport(app=app)
        async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
            return await client.request(
                method,
                path,
                headers={"Authorization": f"Bearer {token}"} if token else {},
                json=body,
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


def test_circle_list_returns_only_callers_active_memberships() -> None:
    identity = VerifiedIdentity("uid-list-member", "Member")
    app, engine = make_app({"member-token": identity})
    user_id, first_circle_id = add_user_circle_membership(
        engine,
        firebase_uid=identity.firebase_uid,
        circle_name="Alpha Circle",
    )
    with Session(engine) as session:
        active_circle = Circle(name="Beta Circle")
        inactive_circle = Circle(name="Inactive Circle")
        other_user = User(firebase_uid="uid-list-other", display_name="Other")
        other_circle = Circle(name="Other Circle")
        session.add_all([active_circle, inactive_circle, other_user, other_circle])
        session.flush()
        session.add_all(
            [
                Membership(
                    user_id=user_id,
                    circle_id=active_circle.id,
                    role="member",
                    status="active",
                ),
                Membership(
                    user_id=user_id,
                    circle_id=inactive_circle.id,
                    role="member",
                    status="inactive",
                ),
                Membership(
                    user_id=other_user.id,
                    circle_id=other_circle.id,
                    role="member",
                    status="active",
                ),
            ]
        )
        session.commit()
        active_circle_id = active_circle.id

    response = request(app, "GET", "/v1/circles?membership=active", "member-token")

    assert response.status_code == 200
    assert response.json()["circles"] == [
        {"id": first_circle_id, "name": "Alpha Circle"},
        {"id": active_circle_id, "name": "Beta Circle"},
    ]
    assert response.json()["requestId"]
    engine.dispose()


def test_circle_list_requires_authenticated_identity() -> None:
    app, engine = make_app({})

    response = request(app, "GET", "/v1/circles?membership=active")

    assert response.status_code == 401
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


def test_organizer_can_revoke_member_and_access_ends_immediately() -> None:
    organizer = VerifiedIdentity("uid-organizer", "Organizer")
    member = VerifiedIdentity("uid-member", "Member")
    app, engine = make_app({"organizer-token": organizer, "member-token": member})
    organizer_id, circle_id = add_user_circle_membership(
        engine,
        firebase_uid=organizer.firebase_uid,
        circle_name="Membership Circle",
        role="organizer",
    )
    with Session(engine) as session:
        member_user = User(firebase_uid=member.firebase_uid, display_name="Member")
        session.add(member_user)
        session.flush()
        target = Membership(
            circle_id=circle_id,
            user_id=member_user.id,
            role="member",
            status="active",
        )
        session.add(target)
        session.commit()
        member_user_id = member_user.id
        membership_id = target.id

    response = request(
        app,
        "POST",
        f"/v1/circles/{circle_id}/memberships/{membership_id}/revoke",
        "organizer-token",
        {"reason": "Repeatedly violated circle rules"},
    )
    repeated_revoke = request(
        app,
        "POST",
        f"/v1/circles/{circle_id}/memberships/{membership_id}/revoke",
        "organizer-token",
        {"reason": "Repeatedly violated circle rules"},
    )
    access = request(app, "GET", f"/v1/circles/{circle_id}", "member-token")

    assert response.status_code == 200
    assert repeated_revoke.status_code == 409
    assert response.json()["status"] == "revoked"
    assert response.json()["circleId"] == circle_id
    assert access.status_code == 404
    with Session(engine) as session:
        membership = session.get(Membership, membership_id)
        event = session.get(MembershipEvent, response.json()["eventId"])
        assert membership is not None and membership.status == "revoked"
        assert event is not None
        assert event.user_id == member_user_id
        assert event.actor_user_id == organizer_id
        assert event.reason == "Repeatedly violated circle rules"
        assert event.previous_status == "active"
        assert event.resulting_status == "revoked"
        assert (
            len(
                session.scalars(
                    select(MembershipEvent).where(MembershipEvent.membership_id == membership_id)
                ).all()
            )
            == 1
        )
    engine.dispose()


def test_member_can_leave_but_cannot_revoke_another_member() -> None:
    organizer = VerifiedIdentity("uid-organizer", "Organizer")
    member = VerifiedIdentity("uid-member", "Member")
    other = VerifiedIdentity("uid-other", "Other")
    app, engine = make_app(
        {
            "organizer-token": organizer,
            "member-token": member,
            "other-token": other,
        }
    )
    add_user_circle_membership(
        engine,
        firebase_uid=organizer.firebase_uid,
        circle_name="Membership Circle",
        role="organizer",
    )
    with Session(engine) as session:
        circle_id = session.scalar(select(Circle.id))
        member_user = User(firebase_uid=member.firebase_uid)
        other_user = User(firebase_uid=other.firebase_uid)
        session.add_all([member_user, other_user])
        session.flush()
        member_membership = Membership(
            circle_id=circle_id, user_id=member_user.id, role="member", status="active"
        )
        other_membership = Membership(
            circle_id=circle_id, user_id=other_user.id, role="member", status="active"
        )
        session.add_all([member_membership, other_membership])
        session.commit()
        member_membership_id = member_membership.id
        other_membership_id = other_membership.id

    unauthorized = request(
        app,
        "POST",
        f"/v1/circles/{circle_id}/memberships/{other_membership_id}/revoke",
        "member-token",
        {"reason": "Not allowed"},
    )
    self_promotion = request(
        app,
        "POST",
        f"/v1/circles/{circle_id}/memberships/{member_membership_id}/promote-organizer",
        "member-token",
    )
    left = request(
        app,
        "POST",
        f"/v1/circles/{circle_id}/memberships/me/leave",
        "member-token",
    )
    repeated_leave = request(
        app,
        "POST",
        f"/v1/circles/{circle_id}/memberships/me/leave",
        "member-token",
    )
    access = request(app, "GET", f"/v1/circles/{circle_id}", "member-token")

    assert unauthorized.status_code == 403
    assert self_promotion.status_code == 403
    assert left.status_code == 200
    assert repeated_leave.status_code == 409
    assert left.json()["membershipId"] == member_membership_id
    assert left.json()["status"] == "inactive"
    assert access.status_code == 404
    with Session(engine) as session:
        event = session.get(MembershipEvent, left.json()["eventId"])
        assert event is not None
        assert event.action == "member_left"
        assert event.reason is None
        assert (
            len(
                session.scalars(
                    select(MembershipEvent).where(
                        MembershipEvent.membership_id == member_membership_id
                    )
                ).all()
            )
            == 1
        )
    engine.dispose()


def test_revoke_requires_reason_and_final_organizer_cannot_leave() -> None:
    organizer = VerifiedIdentity("uid-organizer", "Organizer")
    app, engine = make_app({"organizer-token": organizer})
    _, circle_id = add_user_circle_membership(
        engine,
        firebase_uid=organizer.firebase_uid,
        circle_name="Organizer Circle",
        role="organizer",
    )

    missing_reason = request(
        app,
        "POST",
        f"/v1/circles/{circle_id}/memberships/missing/revoke",
        "organizer-token",
        {"reason": "   "},
    )
    final_organizer_leave = request(
        app,
        "POST",
        f"/v1/circles/{circle_id}/memberships/me/leave",
        "organizer-token",
        {},
    )

    assert missing_reason.status_code == 422
    assert final_organizer_leave.status_code == 409
    with Session(engine) as session:
        assert session.scalar(select(MembershipEvent)) is None
    engine.dispose()


def test_promoted_successor_allows_previous_final_organizer_to_leave() -> None:
    organizer = VerifiedIdentity("uid-organizer", "Organizer")
    member = VerifiedIdentity("uid-member", "Member")
    app, engine = make_app({"organizer-token": organizer, "member-token": member})
    add_user_circle_membership(
        engine,
        firebase_uid=organizer.firebase_uid,
        circle_name="Organizer Circle",
        role="organizer",
    )
    with Session(engine) as session:
        circle_id = session.scalar(select(Circle.id))
        member_user = User(firebase_uid=member.firebase_uid)
        session.add(member_user)
        session.flush()
        membership = Membership(
            circle_id=circle_id,
            user_id=member_user.id,
            role="member",
            status="active",
        )
        session.add(membership)
        session.commit()
        membership_id = membership.id

    promoted = request(
        app,
        "POST",
        f"/v1/circles/{circle_id}/memberships/{membership_id}/promote-organizer",
        "organizer-token",
    )
    left = request(
        app,
        "POST",
        f"/v1/circles/{circle_id}/memberships/me/leave",
        "organizer-token",
        {},
    )

    assert promoted.status_code == 200
    assert promoted.json()["role"] == "organizer"
    assert left.status_code == 200
    with Session(engine) as session:
        events = session.scalars(select(MembershipEvent).order_by(MembershipEvent.action)).all()
        assert {event.action for event in events} == {"organizer_promoted", "member_left"}
        assert (
            session.scalar(
                select(Membership).where(
                    Membership.circle_id == circle_id,
                    Membership.status == "active",
                    Membership.role == "organizer",
                )
            )
            is not None
        )
    engine.dispose()


def test_membership_transition_rolls_back_when_audit_insert_fails() -> None:
    organizer = VerifiedIdentity("uid-organizer", "Organizer")
    member = VerifiedIdentity("uid-member", "Member")
    app, engine = make_app({"organizer-token": organizer, "member-token": member})
    add_user_circle_membership(
        engine,
        firebase_uid=organizer.firebase_uid,
        circle_name="Membership Circle",
        role="organizer",
    )
    with Session(engine) as session:
        circle_id = session.scalar(select(Circle.id))
        member_user = User(firebase_uid=member.firebase_uid)
        session.add(member_user)
        session.flush()
        membership = Membership(
            circle_id=circle_id,
            user_id=member_user.id,
            role="member",
            status="active",
        )
        session.add(membership)
        session.commit()
        membership_id = membership.id
        session.execute(
            text(
                "CREATE TRIGGER fail_membership_event BEFORE INSERT ON membership_events "
                "BEGIN SELECT RAISE(ABORT, 'injected audit failure'); END"
            )
        )
        session.commit()

    response = request(
        app,
        "POST",
        f"/v1/circles/{circle_id}/memberships/{membership_id}/revoke",
        "organizer-token",
        {"reason": "Test rollback"},
    )

    assert response.status_code == 503
    with Session(engine) as session:
        membership = session.get(Membership, membership_id)
        assert membership is not None and membership.status == "active"
        assert session.scalar(select(MembershipEvent)) is None
    engine.dispose()
