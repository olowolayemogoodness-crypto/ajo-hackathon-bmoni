import os
from concurrent.futures import ThreadPoolExecutor
from datetime import date, timedelta
from pathlib import Path
from threading import Barrier

import pytest
from alembic import command
from alembic.config import Config
from fastapi import HTTPException
from sqlalchemy import create_engine, func, inspect, select, text
from sqlalchemy.engine import make_url
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.auth.identity import VerifiedIdentity
from app.core.config import Settings, get_settings
from app.modules.circles.demo_service import (
    accept_demo_invitation,
    activate_demo_circle,
    approve_demo_payout,
    create_demo_circle,
    get_demo_summary,
    record_simulated_contribution,
    settle_demo_payout,
)
from app.modules.circles.models import (
    CirclePayout,
    CirclePayoutEvent,
    SimulatedContribution,
)
from app.modules.users.models import User

POSTGRES_URL = os.environ.get("AJO_TEST_POSTGRES_URL")
EXPECTED_TABLES = {
    "alembic_version",
    "users",
    "circles",
    "memberships",
    "membership_events",
    "circle_invitations",
    "circle_periods",
    "circle_obligations",
    "simulated_contributions",
    "circle_payouts",
    "circle_payout_events",
}


@pytest.mark.postgres
@pytest.mark.skipif(
    not POSTGRES_URL,
    reason="set AJO_TEST_POSTGRES_URL to a disposable *_test database",
)
def test_postgres_demo_cycle_serializes_partial_contributions_and_settlement(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    database_url = make_url(POSTGRES_URL)
    if not database_url.database or not database_url.database.endswith("_test"):
        pytest.fail("AJO_TEST_POSTGRES_URL database name must end in _test")

    engine = create_engine(database_url)
    try:
        existing_tables = set(inspect(engine).get_table_names())
        unexpected_tables = existing_tables - EXPECTED_TABLES
        if unexpected_tables:
            pytest.fail(f"Expected a dedicated test database; found tables: {unexpected_tables}")

        backend_root = Path(__file__).resolve().parents[1]
        alembic_config = Config(str(backend_root / "alembic.ini"))
        alembic_config.set_main_option("script_location", str(backend_root / "migrations"))
        monkeypatch.setenv("AJO_DATABASE_URL", str(database_url))
        get_settings.cache_clear()
        if "alembic_version" in existing_tables:
            command.downgrade(alembic_config, "base")
        elif existing_tables:
            pytest.fail("Refusing to reset tables without an Alembic revision in the test database")
        command.upgrade(alembic_config, "head")
        assert EXPECTED_TABLES.issubset(inspect(engine).get_table_names())

        settings = Settings(
            database_url=str(database_url),
            environment="test",
            demo_mode=True,
            synthetic_data=True,
            demo_operator_firebase_uids="postgres-demo-operator",
        )
        organizer = VerifiedIdentity("postgres-demo-organizer", "Organizer")
        member = VerifiedIdentity("postgres-demo-member", "Member")
        operator = VerifiedIdentity("postgres-demo-operator", "Demo Operator")

        with Session(engine) as session, session.begin():
            session.add(User(id="postgres-demo-operator", firebase_uid=operator.firebase_uid))

        with Session(engine) as session:
            created = create_demo_circle(
                session,
                organizer,
                "request-pg-create",
                name="PostgreSQL Demo",
                max_members=3,
                contribution_kobo=100_000,
                accepted_rules_version="ajo-demo-rules-1.0.0",
                settings=settings,
            )
            accepted = accept_demo_invitation(
                session,
                member,
                "request-pg-accept",
                code=created["invitationCode"],
                accepted_rules_version=created["rulesVersion"],
                settings=settings,
            )
            activate_demo_circle(
                session,
                organizer,
                created["circleId"],
                "request-pg-activate",
                payout_recipient_membership_id=accepted["membershipId"],
                first_due_date=date.today() + timedelta(days=7),
                settings=settings,
            )
            organizer_membership_id = created["organizerMembershipId"]

        barrier = Barrier(2)

        def record_partial(key: str) -> str | int:
            with Session(engine) as session:
                try:
                    barrier.wait(timeout=15)
                    record_simulated_contribution(
                        session,
                        operator,
                        created["circleId"],
                        organizer_membership_id,
                        f"request-{key}",
                        amount_kobo=60_000,
                        idempotency_key=key,
                        settings=settings,
                    )
                    return "recorded"
                except HTTPException as exc:
                    return exc.status_code

        with ThreadPoolExecutor(max_workers=2) as executor:
            results = list(executor.map(record_partial, ("partial-a", "partial-b")))
        assert sorted(results, key=str) == sorted(("recorded", 422), key=str)

        with Session(engine) as session:
            organizer_obligation = session.scalar(
                select(SimulatedContribution.obligation_id).where(
                    SimulatedContribution.circle_id == created["circleId"]
                )
            )
            assert organizer_obligation is not None
            assert (
                session.scalar(
                    select(func.sum(SimulatedContribution.amount_kobo)).where(
                        SimulatedContribution.obligation_id == organizer_obligation
                    )
                )
                == 60_000
            )

        with engine.begin() as connection:
            connection.execute(
                text(
                    "CREATE FUNCTION fail_demo_contribution_insert() RETURNS trigger "
                    "LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION "
                    "'injected simulated contribution failure'; END; $$"
                )
            )
            connection.execute(
                text(
                    "CREATE TRIGGER tr_fail_demo_contribution_insert "
                    "BEFORE INSERT ON simulated_contributions FOR EACH ROW "
                    "EXECUTE FUNCTION fail_demo_contribution_insert()"
                )
            )
        try:
            with Session(engine) as session:
                with pytest.raises(SQLAlchemyError):
                    record_simulated_contribution(
                        session,
                        operator,
                        created["circleId"],
                        organizer_membership_id,
                        "request-failed-event",
                        amount_kobo=40_000,
                        idempotency_key="failed-event",
                        settings=settings,
                    )
        finally:
            with engine.begin() as connection:
                connection.execute(
                    text(
                        "DROP TRIGGER IF EXISTS tr_fail_demo_contribution_insert "
                        "ON simulated_contributions"
                    )
                )
                connection.execute(text("DROP FUNCTION IF EXISTS fail_demo_contribution_insert()"))

        with Session(engine) as session:
            assert (
                session.scalar(
                    select(func.sum(SimulatedContribution.amount_kobo)).where(
                        SimulatedContribution.obligation_id == organizer_obligation
                    )
                )
                == 60_000
            )
            assert (
                session.scalar(
                    select(SimulatedContribution.id).where(
                        SimulatedContribution.idempotency_key == "failed-event"
                    )
                )
                is None
            )

            record_simulated_contribution(
                session,
                operator,
                created["circleId"],
                organizer_membership_id,
                "request-organizer-remainder",
                amount_kobo=40_000,
                idempotency_key="organizer-remainder",
                settings=settings,
            )
            record_simulated_contribution(
                session,
                operator,
                created["circleId"],
                accepted["membershipId"],
                "request-member-full",
                amount_kobo=100_000,
                idempotency_key="member-full",
                settings=settings,
            )
            summary = get_demo_summary(session, organizer, created["circleId"], settings)
            assert summary["shortfallKobo"] == 0
            assert summary["payout"]["eligible"] is True
            approve_demo_payout(
                session,
                organizer,
                created["circleId"],
                "request-pg-approve",
                settings,
            )
            settlement = settle_demo_payout(
                session,
                operator,
                created["circleId"],
                "request-pg-settle",
                settings,
            )
            assert settlement["status"] == "settled"
            assert settlement["mode"] == "simulated"

            assert session.scalar(select(func.count()).select_from(CirclePayoutEvent)) == 2
            assert session.scalar(select(CirclePayout.status)) == "settled"
    finally:
        engine.dispose()
        get_settings.cache_clear()
