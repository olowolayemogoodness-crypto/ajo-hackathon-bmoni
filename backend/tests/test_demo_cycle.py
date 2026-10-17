import asyncio
from datetime import date, timedelta

import httpx
import pytest
from fastapi import FastAPI, HTTPException
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.auth.identity import VerifiedIdentity
from app.core.config import Settings
from app.core.demo_rules import DEMO_RULES_VERSION
from app.db.base import Base
from app.main import create_app
from app.modules.circles.demo_service import (
    accept_demo_invitation,
    activate_demo_circle,
    answer_demo_question,
    approve_demo_payout,
    create_demo_circle,
    get_demo_summary,
    inspect_demo_invitation,
    record_simulated_contribution,
    settle_demo_payout,
)
from app.modules.circles.models import (
    Circle,
    CirclePayout,
    CirclePayoutEvent,
    CirclePeriod,
    MembershipEvent,
)
from app.modules.users.models import User


class DemoVerifier:
    def __init__(self, identities: dict[str, VerifiedIdentity]) -> None:
        self.identities = identities

    def verify(self, token: str) -> VerifiedIdentity:
        if token not in self.identities:
            raise ValueError("invalid token")
        return self.identities[token]


def _api_request(
    app: FastAPI,
    method: str,
    path: str,
    token: str,
    body: dict | None = None,
    extra_headers: dict[str, str] | None = None,
) -> httpx.Response:
    async def send() -> httpx.Response:
        transport = httpx.ASGITransport(app=app)
        async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
            return await client.request(
                method,
                path,
                headers={"Authorization": f"Bearer {token}", **(extra_headers or {})},
                json=body,
            )

    return asyncio.run(send())


def test_local_demo_one_period_cycle_uses_authoritative_backend_state() -> None:
    engine = create_engine(
        "sqlite+pysqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    settings = Settings(
        database_url="sqlite+pysqlite://",
        environment="test",
        demo_mode=True,
        synthetic_data=True,
        demo_operator_firebase_uids="demo-operator-uid",
    )
    organizer_identity = VerifiedIdentity("organizer-uid", "Organizer")
    member_identity = VerifiedIdentity("member-uid", "Member")
    operator_identity = VerifiedIdentity("demo-operator-uid", "Demo Operator")

    with Session(engine) as session:
        created = create_demo_circle(
            session,
            organizer_identity,
            "request-create",
            name="Synthetic Ajo",
            max_members=3,
            contribution_kobo=100_000,
            accepted_rules_version=DEMO_RULES_VERSION,
            settings=settings,
        )
        inspected = inspect_demo_invitation(session, created["invitationCode"], settings)
        assert inspected["rulesVersion"] == DEMO_RULES_VERSION
        assert "synthetic" in str(inspected["rulesText"]).lower()

        accepted = accept_demo_invitation(
            session,
            member_identity,
            "request-accept",
            code=created["invitationCode"],
            accepted_rules_version=DEMO_RULES_VERSION,
            settings=settings,
        )
        with pytest.raises(HTTPException) as repeated_accept:
            accept_demo_invitation(
                session,
                member_identity,
                "request-accept-again",
                code=created["invitationCode"],
                accepted_rules_version=DEMO_RULES_VERSION,
                settings=settings,
            )
        assert repeated_accept.value.status_code == 409

        activated = activate_demo_circle(
            session,
            organizer_identity,
            created["circleId"],
            "request-activate",
            payout_recipient_membership_id=accepted["membershipId"],
            first_due_date=date.today() + timedelta(days=7),
            settings=settings,
        )
        assert activated["status"] == "active"
        organizer_membership_id = created["organizerMembershipId"]

        partial = record_simulated_contribution(
            session,
            operator_identity,
            created["circleId"],
            organizer_membership_id,
            "request-contribution-1",
            amount_kobo=50_000,
            idempotency_key="operator-obligation-part-1",
            settings=settings,
        )
        repeated_partial = record_simulated_contribution(
            session,
            operator_identity,
            created["circleId"],
            organizer_membership_id,
            "request-contribution-replay",
            amount_kobo=50_000,
            idempotency_key="operator-obligation-part-1",
            settings=settings,
        )
        assert partial["contributionId"] == repeated_partial["contributionId"]
        assert repeated_partial["idempotentReplay"] is True

        summary = get_demo_summary(session, organizer_identity, created["circleId"], settings)
        assert summary["shortfallKobo"] == 150_000
        assert summary["payout"]["eligible"] is False

        with pytest.raises(HTTPException) as excess:
            record_simulated_contribution(
                session,
                operator_identity,
                created["circleId"],
                organizer_membership_id,
                "request-excess",
                amount_kobo=50_001,
                idempotency_key="operator-obligation-excess",
                settings=settings,
            )
        assert excess.value.status_code == 422

        record_simulated_contribution(
            session,
            operator_identity,
            created["circleId"],
            organizer_membership_id,
            "request-contribution-2",
            amount_kobo=50_000,
            idempotency_key="operator-obligation-part-2",
            settings=settings,
        )
        record_simulated_contribution(
            session,
            operator_identity,
            created["circleId"],
            accepted["membershipId"],
            "request-contribution-3",
            amount_kobo=100_000,
            idempotency_key="operator-member-contribution",
            settings=settings,
        )
        summary = get_demo_summary(session, organizer_identity, created["circleId"], settings)
        assert summary["collectedKobo"] == 200_000
        assert summary["shortfallKobo"] == 0
        assert summary["payout"]["eligible"] is True

        approved = approve_demo_payout(
            session,
            organizer_identity,
            created["circleId"],
            "request-approve",
            settings,
        )
        assert approved["status"] == "processing"
        settled = settle_demo_payout(
            session,
            operator_identity,
            created["circleId"],
            "request-settle",
            settings,
        )
        replayed_settlement = settle_demo_payout(
            session,
            operator_identity,
            created["circleId"],
            "request-settle-replay",
            settings,
        )
        assert settled["status"] == "settled"
        assert settled["mode"] == "simulated"
        assert replayed_settlement["eventId"] == settled["eventId"]
        assert replayed_settlement["idempotentReplay"] is True
        contribution_replay_after_settlement = record_simulated_contribution(
            session,
            operator_identity,
            created["circleId"],
            accepted["membershipId"],
            "request-contribution-after-settle",
            amount_kobo=100_000,
            idempotency_key="operator-member-contribution",
            settings=settings,
        )
        assert contribution_replay_after_settlement["idempotentReplay"] is True
        settled_summary = get_demo_summary(
            session,
            organizer_identity,
            created["circleId"],
            settings,
        )
        assert settled_summary["payout"]["eligible"] is False
        assert "is settled" in settled_summary["explanation"]
        assert "No action needed" in settled_summary["nextAction"]

        circle = session.get(Circle, created["circleId"])
        payout = session.scalar(select(CirclePayout))
        payout_events = session.scalars(select(CirclePayoutEvent)).all()
        membership_events = session.scalars(select(MembershipEvent)).all()
        assert circle is not None and circle.status == "completed" and circle.synthetic
        assert payout is not None and payout.status == "settled"
        assert {event.action for event in payout_events} == {"approved", "simulated_settled"}
        assert len(membership_events) == 2
        demo_users = session.scalars(
            select(User).where(
                User.firebase_uid.in_(("organizer-uid", "member-uid", "demo-operator-uid"))
            )
        ).all()
        assert len(demo_users) == 3
        assert all(user.display_name is None for user in demo_users)

    engine.dispose()


def test_demo_api_creates_accepts_activates_and_reports_circle() -> None:
    engine = create_engine(
        "sqlite+pysqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    organizer_identity = VerifiedIdentity("api-organizer-uid", "Organizer")
    member_identity = VerifiedIdentity("api-member-uid", "Member")
    operator_identity = VerifiedIdentity("demo-operator-uid", "Demo Operator")
    outsider_identity = VerifiedIdentity("api-outsider-uid", "Outsider")
    settings = Settings(
        database_url="sqlite+pysqlite://",
        environment="test",
        demo_mode=True,
        synthetic_data=True,
        demo_operator_firebase_uids="demo-operator-uid",
    )
    app = create_app(
        settings=settings,
        engine=engine,
        identity_verifier=DemoVerifier(
            {
                "organizer-token": organizer_identity,
                "member-token": member_identity,
                "operator-token": operator_identity,
                "outsider-token": outsider_identity,
            }
        ),
    )

    rules = _api_request(app, "GET", "/v1/demo/rules", "organizer-token")
    assert rules.status_code == 200
    assert rules.json()["version"] == DEMO_RULES_VERSION

    created = _api_request(
        app,
        "POST",
        "/v1/circles",
        "organizer-token",
        {
            "name": "API Demo Circle",
            "maxMembers": 3,
            "contributionKobo": 125_000,
            "acceptedRulesVersion": DEMO_RULES_VERSION,
        },
    )
    assert created.status_code == 201
    create_data = created.json()

    inspected = _api_request(
        app,
        "POST",
        "/v1/invitations/inspect",
        "member-token",
        {"invitationCode": create_data["invitationCode"]},
    )
    assert inspected.status_code == 200
    assert inspected.json()["rulesVersion"] == DEMO_RULES_VERSION
    assert "moves no real money" in inspected.json()["rulesText"]

    mismatch = _api_request(
        app,
        "POST",
        "/v1/invitations/accept",
        "member-token",
        {
            "invitationCode": create_data["invitationCode"],
            "acceptedRulesVersion": "rules_v1",
        },
    )
    assert mismatch.status_code == 409

    accepted = _api_request(
        app,
        "POST",
        "/v1/invitations/accept",
        "member-token",
        {
            "invitationCode": create_data["invitationCode"],
            "acceptedRulesVersion": DEMO_RULES_VERSION,
        },
    )
    assert accepted.status_code == 201
    accepted_membership_id = accepted.json()["membershipId"]
    with Session(engine) as session:
        circle = session.get(Circle, create_data["circleId"])
        acceptance_event = session.scalar(
            select(MembershipEvent).where(
                MembershipEvent.circle_id == create_data["circleId"],
                MembershipEvent.membership_id == accepted_membership_id,
            )
        )
        assert circle is not None
        assert circle.current_rules_version == DEMO_RULES_VERSION
        assert acceptance_event is not None
        assert acceptance_event.accepted_rules_version == DEMO_RULES_VERSION

    setup = _api_request(
        app,
        "GET",
        f"/v1/circles/{create_data['circleId']}/demo-setup",
        "organizer-token",
    )
    assert setup.status_code == 200
    assert len(setup.json()["members"]) == 2
    assert setup.json()["canManageCircle"] is True
    member_membership_id = accepted.json()["membershipId"]

    member_setup = _api_request(
        app,
        "GET",
        f"/v1/circles/{create_data['circleId']}/demo-setup",
        "member-token",
    )
    assert member_setup.status_code == 200
    assert member_setup.json()["currentRole"] == "member"
    assert member_setup.json()["canManageCircle"] is False

    activated = _api_request(
        app,
        "POST",
        f"/v1/circles/{create_data['circleId']}/activate",
        "organizer-token",
        {
            "payoutRecipientMembershipId": member_membership_id,
            "firstDueDate": (date.today() + timedelta(days=7)).isoformat(),
        },
    )
    assert activated.status_code == 200

    second_activation = _api_request(
        app,
        "POST",
        f"/v1/circles/{create_data['circleId']}/activate",
        "member-token",
        {
            "payoutRecipientMembershipId": create_data["organizerMembershipId"],
            "firstDueDate": (date.today() + timedelta(days=7)).isoformat(),
        },
    )
    assert second_activation.status_code == 404 or second_activation.status_code == 403

    summary = _api_request(
        app,
        "GET",
        f"/v1/circles/{create_data['circleId']}/demo-summary",
        "member-token",
    )
    assert summary.status_code == 200
    assert summary.json()["circle"]["status"] == "active"
    assert summary.json()["shortfallKobo"] == 250_000
    assert summary.json()["payout"]["eligible"] is False

    explanation = _api_request(
        app,
        "POST",
        "/v1/assistant/queries",
        "member-token",
        {
            "circleId": create_data["circleId"],
            "question": "Why is the payout not eligible?",
        },
    )
    assert explanation.status_code == 200
    assert "250000 kobo" in explanation.json()["answer"]
    assert explanation.json()["facts"]["shortfallKobo"] == 250_000

    outsider_question = _api_request(
        app,
        "POST",
        "/v1/assistant/queries",
        "outsider-token",
        {
            "circleId": create_data["circleId"],
            "question": "What is the balance?",
        },
    )
    assert outsider_question.status_code == 404

    unauthorized_contribution = _api_request(
        app,
        "POST",
        f"/v1/circles/{create_data['circleId']}/demo/contributions/"
        f"{create_data['organizerMembershipId']}",
        "member-token",
        {"amountKobo": 125_000},
        {"Idempotency-Key": "member-must-not-operate-demo"},
    )
    assert unauthorized_contribution.status_code == 403

    for membership_id, idempotency_key in (
        (create_data["organizerMembershipId"], "api-organizer-contribution"),
        (accepted.json()["membershipId"], "api-member-contribution"),
    ):
        contribution = _api_request(
            app,
            "POST",
            f"/v1/circles/{create_data['circleId']}/demo/contributions/{membership_id}",
            "operator-token",
            {"amountKobo": 125_000},
            {"Idempotency-Key": idempotency_key},
        )
        assert contribution.status_code == 200
        assert contribution.json()["mode"] == "simulated"

    summary = _api_request(
        app,
        "GET",
        f"/v1/circles/{create_data['circleId']}/demo-summary",
        "member-token",
    )
    assert summary.json()["shortfallKobo"] == 0
    assert summary.json()["payout"]["eligible"] is True

    approved = _api_request(
        app,
        "POST",
        f"/v1/circles/{create_data['circleId']}/payout/approve",
        "organizer-token",
    )
    assert approved.status_code == 200
    assert approved.json()["status"] == "processing"
    unauthorized_settlement = _api_request(
        app,
        "POST",
        f"/v1/circles/{create_data['circleId']}/demo/payout/settle",
        "member-token",
    )
    assert unauthorized_settlement.status_code == 403
    settled = _api_request(
        app,
        "POST",
        f"/v1/circles/{create_data['circleId']}/demo/payout/settle",
        "operator-token",
    )
    assert settled.status_code == 200
    assert settled.json()["status"] == "settled"
    assert settled.json()["mode"] == "simulated"
    settled_answer = _api_request(
        app,
        "POST",
        "/v1/assistant/queries",
        "member-token",
        {
            "circleId": create_data["circleId"],
            "question": "Has the payout settled?",
        },
    )
    assert settled_answer.status_code == 200
    assert "No real money moved" in settled_answer.json()["answer"]
    engine.dispose()


def test_assistant_explains_payout_state_only_from_available_evidence() -> None:
    engine = create_engine(
        "sqlite+pysqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    settings = Settings(
        database_url="sqlite+pysqlite://",
        environment="test",
        demo_mode=True,
        synthetic_data=True,
        demo_operator_firebase_uids="demo-operator-uid",
    )
    organizer_identity = VerifiedIdentity("organizer-uid", "Organizer")
    member_identity = VerifiedIdentity("member-uid", "Member")
    operator_identity = VerifiedIdentity("demo-operator-uid", "Demo Operator")

    with Session(engine) as session:
        created = create_demo_circle(
            session,
            organizer_identity,
            "request-create",
            name="State Explanations",
            max_members=2,
            contribution_kobo=100_000,
            accepted_rules_version=DEMO_RULES_VERSION,
            settings=settings,
        )
        accepted = accept_demo_invitation(
            session,
            member_identity,
            "request-accept",
            code=created["invitationCode"],
            accepted_rules_version=DEMO_RULES_VERSION,
            settings=settings,
        )
        activate_demo_circle(
            session,
            organizer_identity,
            created["circleId"],
            "request-activate",
            payout_recipient_membership_id=accepted["membershipId"],
            first_due_date=date.today() + timedelta(days=7),
            settings=settings,
        )

        shortfall_answer = answer_demo_question(
            session,
            organizer_identity,
            created["circleId"],
            "Why is my payout still pending?",
            settings,
        )
        assert "200000 kobo remains outstanding" in shortfall_answer["answer"]
        organizer_summary = get_demo_summary(
            session, organizer_identity, created["circleId"], settings
        )
        member_summary = get_demo_summary(session, member_identity, created["circleId"], settings)
        assert "100000 kobo outstanding" in organizer_summary["nextAction"]
        assert "100000 kobo outstanding" in member_summary["nextAction"]
        assert "demo operator" in member_summary["nextAction"]

        period_id = session.scalar(
            select(CirclePeriod.id).where(CirclePeriod.circle_id == created["circleId"])
        )
        payout = session.scalar(
            select(CirclePayout).where(CirclePayout.period_id == period_id)
        )
        assert payout is not None
        payout.status = "held"
        session.commit()
        held_answer = answer_demo_question(
            session,
            organizer_identity,
            created["circleId"],
            "Why is my payout still pending?",
            settings,
        )
        assert "on hold" in held_answer["answer"].lower()
        assert "outstanding" not in held_answer["answer"].lower()
        held_summary = get_demo_summary(session, member_identity, created["circleId"], settings)
        assert "hold reason" in held_summary["nextAction"]

        record_simulated_contribution(
            session,
            operator_identity,
            created["circleId"],
            created["organizerMembershipId"],
            "request-contribution-1",
            amount_kobo=100_000,
            idempotency_key="assistant-approval-test",
            settings=settings,
        )
        record_simulated_contribution(
            session,
            operator_identity,
            created["circleId"],
            accepted["membershipId"],
            "request-contribution-2",
            amount_kobo=100_000,
            idempotency_key="assistant-approval-test-member",
            settings=settings,
        )
        payout = session.scalar(
            select(CirclePayout).where(CirclePayout.period_id == period_id)
        )
        payout.status = "awaiting_approval"
        session.commit()
        approval_answer = answer_demo_question(
            session,
            organizer_identity,
            created["circleId"],
            "Why is my payout still pending?",
            settings,
        )
        assert "awaiting organizer approval" in approval_answer["answer"].lower()
        approval_summary = get_demo_summary(
            session, organizer_identity, created["circleId"], settings
        )
        member_approval_summary = get_demo_summary(
            session, member_identity, created["circleId"], settings
        )
        assert "Review the eligible payout" in approval_summary["nextAction"]
        assert "Wait for the organizer" in member_approval_summary["nextAction"]

        payout.status = "processing"
        session.commit()
        processing_answer = answer_demo_question(
            session,
            organizer_identity,
            created["circleId"],
            "Why is my payout still pending?",
            settings,
        )
        assert "processing" in processing_answer["answer"].lower()
        assert "awaiting explicit simulated settlement" in processing_answer["answer"].lower()
        assert "organizer approved" not in processing_answer["answer"].lower()
        processing_summary = get_demo_summary(
            session, organizer_identity, created["circleId"], settings
        )
        assert "restricted to the demo operator" in processing_summary["nextAction"]
    engine.dispose()
