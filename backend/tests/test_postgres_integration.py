import asyncio
import os
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from threading import Barrier

import httpx
import pytest
from alembic import command
from alembic.config import Config
from fastapi import HTTPException
from sqlalchemy import create_engine, inspect, select, text
from sqlalchemy.engine import make_url
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy.orm import Session

from app.auth.identity import VerifiedIdentity
from app.core.config import get_settings
from app.main import create_app
from app.modules.circles.membership_service import leave_circle
from app.modules.circles.models import Circle, Membership, MembershipEvent
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
        schema_tables = {
            "alembic_version",
            "users",
            "circles",
            "memberships",
            "membership_events",
        }
        existing_tables = set(inspect(engine).get_table_names())
        unexpected_tables = existing_tables - schema_tables
        if unexpected_tables:
            pytest.fail(
                f"Expected a dedicated test database; found other tables: {unexpected_tables}"
            )

        monkeypatch.setenv("AJO_DATABASE_URL", str(database_url))
        get_settings.cache_clear()
        backend_root = Path(__file__).resolve().parents[1]
        alembic_config = Config(str(backend_root / "alembic.ini"))
        alembic_config.set_main_option("script_location", str(backend_root / "migrations"))
        if "alembic_version" in existing_tables:
            command.downgrade(alembic_config, "base")
        elif existing_tables:
            pytest.fail("Refusing to reset tables without an Alembic revision in the test database")
        assert set(inspect(engine).get_table_names()).issubset({"alembic_version"})

        with engine.connect() as connection:
            postgres_version = connection.scalar(text("SHOW server_version"))
        print(f"PostgreSQL server version: {postgres_version}")

        command.upgrade(alembic_config, "head")
        assert schema_tables.issubset(inspect(engine).get_table_names())

        inspector = inspect(engine)
        membership_foreign_keys = {
            (foreign_key["constrained_columns"][0], foreign_key["referred_table"]): (
                foreign_key["options"].get("ondelete")
            )
            for foreign_key in inspector.get_foreign_keys("memberships")
        }
        assert membership_foreign_keys == {
            ("circle_id", "circles"): "RESTRICT",
            ("user_id", "users"): "RESTRICT",
        }
        assert any(
            unique_constraint["column_names"] == ["circle_id", "user_id"]
            for unique_constraint in inspector.get_unique_constraints("memberships")
        )
        check_constraints = {
            constraint["name"] for constraint in inspector.get_check_constraints("memberships")
        }
        assert {"ck_memberships_role", "ck_memberships_status"}.issubset(check_constraints)

        with Session(engine) as session, session.begin():
            session.add_all(
                [
                    User(id="user-constraints", firebase_uid="firebase-constraints"),
                    User(id="user-concurrent", firebase_uid="firebase-concurrent"),
                    Circle(id="circle-constraints", name="Constraint Circle"),
                    Circle(id="circle-concurrent", name="Concurrent Circle"),
                ]
            )

        def expect_constraint_failure(membership: Membership) -> None:
            with pytest.raises(IntegrityError):
                with Session(engine) as session, session.begin():
                    session.add(membership)
                    session.flush()

        expect_constraint_failure(
            Membership(
                id="invalid-role",
                circle_id="circle-constraints",
                user_id="user-constraints",
                role="owner",
                status="active",
            )
        )
        expect_constraint_failure(
            Membership(
                id="invalid-status",
                circle_id="circle-constraints",
                user_id="user-constraints",
                role="member",
                status="pending",
            )
        )
        expect_constraint_failure(
            Membership(
                id="invalid-circle-fk",
                circle_id="missing-circle",
                user_id="user-constraints",
                role="member",
                status="active",
            )
        )
        expect_constraint_failure(
            Membership(
                id="invalid-user-fk",
                circle_id="circle-constraints",
                user_id="missing-user",
                role="member",
                status="active",
            )
        )

        with pytest.raises(RuntimeError, match="force transaction rollback"):
            with Session(engine) as session, session.begin():
                session.add(
                    Membership(
                        id="rolled-back-membership",
                        circle_id="circle-constraints",
                        user_id="user-constraints",
                        role="member",
                        status="active",
                    )
                )
                session.flush()
                raise RuntimeError("force transaction rollback")
        with Session(engine) as session:
            assert session.get(Membership, "rolled-back-membership") is None

        barrier = Barrier(2)

        def insert_concurrent_membership(membership_id: str) -> bool:
            try:
                with Session(engine) as session, session.begin():
                    barrier.wait()
                    session.add(
                        Membership(
                            id=membership_id,
                            circle_id="circle-concurrent",
                            user_id="user-concurrent",
                            role="member",
                            status="active",
                        )
                    )
                return True
            except IntegrityError:
                return False

        with ThreadPoolExecutor(max_workers=2) as executor:
            membership_results = list(
                executor.map(
                    insert_concurrent_membership,
                    ("concurrent-membership-1", "concurrent-membership-2"),
                )
            )
        assert sorted(membership_results) == [False, True]
        with Session(engine) as session:
            memberships = session.scalars(
                select(Membership).where(
                    Membership.circle_id == "circle-concurrent",
                    Membership.user_id == "user-concurrent",
                )
            ).all()
            assert len(memberships) == 1

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

        with Session(engine) as session, session.begin():
            session.add_all(
                [
                    User(id="user-organizer-a", firebase_uid="firebase-organizer-a"),
                    User(id="user-organizer-b", firebase_uid="firebase-organizer-b"),
                    Circle(id="circle-organizers", name="Organizer Circle"),
                ]
            )
            session.flush()
            session.add_all(
                [
                    Membership(
                        id="membership-organizer-a",
                        circle_id="circle-organizers",
                        user_id="user-organizer-a",
                        role="organizer",
                        status="active",
                    ),
                    Membership(
                        id="membership-organizer-b",
                        circle_id="circle-organizers",
                        user_id="user-organizer-b",
                        role="organizer",
                        status="active",
                    ),
                ]
            )

        organizer_barrier = Barrier(2)

        def leave_as_organizer(firebase_uid: str) -> str | int:
            with Session(engine) as session:
                try:
                    organizer_barrier.wait(timeout=15)
                    leave_circle(
                        session,
                        VerifiedIdentity(firebase_uid, firebase_uid),
                        "circle-organizers",
                        f"request-{firebase_uid}",
                        None,
                    )
                    return "left"
                except HTTPException as exc:
                    return exc.status_code

        with ThreadPoolExecutor(max_workers=2) as executor:
            organizer_results = list(
                executor.map(leave_as_organizer, ("firebase-organizer-a", "firebase-organizer-b"))
            )
        assert sorted(organizer_results, key=str) == sorted(("left", 409), key=str)

        with Session(engine) as session, session.begin():
            audit_user = User(id="user-audit-failure", firebase_uid="firebase-audit-failure")
            session.add(audit_user)
            session.flush()
            session.add(
                Membership(
                    id="membership-audit-failure",
                    circle_id="circle-organizers",
                    user_id=audit_user.id,
                    role="member",
                    status="active",
                )
            )

        with engine.begin() as connection:
            connection.execute(
                text(
                    "CREATE FUNCTION fail_membership_event_insert() RETURNS trigger "
                    "LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION "
                    "'injected audit insert failure'; END; $$"
                )
            )
            connection.execute(
                text(
                    "CREATE TRIGGER tr_fail_membership_event_insert "
                    "BEFORE INSERT ON membership_events FOR EACH ROW "
                    "EXECUTE FUNCTION fail_membership_event_insert()"
                )
            )
        try:
            with Session(engine) as session:
                with pytest.raises(SQLAlchemyError):
                    leave_circle(
                        session,
                        VerifiedIdentity("firebase-audit-failure", "Audit Failure"),
                        "circle-organizers",
                        "request-audit-failure",
                        None,
                    )
        finally:
            with engine.begin() as connection:
                connection.execute(
                    text(
                        "DROP TRIGGER IF EXISTS tr_fail_membership_event_insert "
                        "ON membership_events"
                    )
                )
                connection.execute(text("DROP FUNCTION IF EXISTS fail_membership_event_insert()"))

        with Session(engine) as session:
            membership = session.get(Membership, "membership-audit-failure")
            assert membership is not None and membership.status == "active"
            assert (
                session.scalar(
                    select(MembershipEvent.id).where(
                        MembershipEvent.membership_id == "membership-audit-failure"
                    )
                )
                is None
            )

        with Session(engine) as session:
            active_organizers = session.scalars(
                select(Membership).where(
                    Membership.circle_id == "circle-organizers",
                    Membership.status == "active",
                    Membership.role == "organizer",
                )
            ).all()
            assert len(active_organizers) == 1
            assert (
                len(
                    session.scalars(
                        select(MembershipEvent).where(
                            MembershipEvent.circle_id == "circle-organizers"
                        )
                    ).all()
                )
                == 1
            )

            with pytest.raises(SQLAlchemyError):
                with session.begin_nested():
                    event = session.scalar(
                        select(MembershipEvent).where(
                            MembershipEvent.circle_id == "circle-organizers"
                        )
                    )
                    assert event is not None
                    event.reason = "mutated history"
                    session.flush()

        command.downgrade(alembic_config, "base")
        assert set(inspect(engine).get_table_names()).issubset({"alembic_version"})
        command.upgrade(alembic_config, "head")
        assert schema_tables.issubset(inspect(engine).get_table_names())
    finally:
        engine.dispose()
        get_settings.cache_clear()
