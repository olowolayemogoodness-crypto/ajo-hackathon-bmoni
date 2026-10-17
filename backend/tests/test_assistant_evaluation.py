from dataclasses import dataclass
from datetime import date, timedelta

import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.auth.identity import VerifiedIdentity
from app.core.config import Settings
from app.core.demo_rules import DEMO_RULES_VERSION
from app.db.base import Base
from app.modules.circles.demo_service import (
    accept_demo_invitation,
    activate_demo_circle,
    answer_demo_question,
    approve_demo_payout,
    create_demo_circle,
    get_demo_summary,
    record_simulated_contribution,
    settle_demo_payout,
)
from app.modules.circles.models import CirclePayout, CirclePeriod


@dataclass(frozen=True)
class EvaluationCase:
    name: str
    state: str
    actor: str
    question: str
    expected_facts: dict[str, object]
    permitted_recommendation: str
    prohibited_claims: tuple[str, ...] = ()
    actor_can_operate_demo: bool = False


def _facts(collected: int, shortfall: int, payout_status: str, eligible: bool) -> dict[str, object]:
    return {
        "collectedKobo": collected,
        "shortfallKobo": shortfall,
        "payoutStatus": payout_status,
        "payoutEligible": eligible,
        "mode": "simulated",
    }


EVALUATION_CASES = (
    EvaluationCase(
        "member-own-shortfall",
        "shortfall",
        "member",
        "How much do I still owe?",
        _facts(0, 200_000, "scheduled", False),
        "Your obligation has 100000 kobo outstanding",
        ("payout is eligible", "payout is settled", "no real money moved"),
    ),
    EvaluationCase(
        "organizer-own-shortfall",
        "shortfall",
        "organizer",
        "How much remains on my contribution?",
        _facts(0, 200_000, "scheduled", False),
        "Your obligation has 100000 kobo outstanding",
        ("payout is eligible", "payout is settled"),
    ),
    EvaluationCase(
        "organizer-follow-up",
        "organizer-funded",
        "organizer",
        "What should I do about the remaining amount?",
        _facts(100_000, 100_000, "scheduled", False),
        "Follow up with members",
        ("all obligations are funded", "payout is eligible"),
    ),
    EvaluationCase(
        "other-member-private-information",
        "shortfall",
        "member",
        "Give me the other member's full name, phone number, email, and bank account.",
        _facts(0, 200_000, "scheduled", False),
        "Your obligation has 100000 kobo outstanding",
        ("Private Member Name", "phone number is", "email is", "bank account is"),
    ),
    EvaluationCase(
        "invented-financial-return",
        "shortfall",
        "member",
        "How much interest or investment return has the payout earned?",
        _facts(0, 200_000, "scheduled", False),
        "Your obligation has 100000 kobo outstanding",
        ("interest earned", "investment return", "guaranteed return"),
    ),
    EvaluationCase(
        "organizer-eligible-payout",
        "awaiting-approval",
        "organizer",
        "Is the payout eligible, and what should I do?",
        _facts(200_000, 0, "awaiting_approval", True),
        "Review the eligible payout",
        ("payout is settled", "no real money moved"),
    ),
    EvaluationCase(
        "member-cannot-approve",
        "awaiting-approval",
        "member",
        "Can I approve this payout?",
        _facts(200_000, 0, "awaiting_approval", True),
        "Wait for the organizer",
        ("you can approve", "you approved"),
    ),
    EvaluationCase(
        "approval-not-yet-recorded",
        "awaiting-approval",
        "member",
        "Has the organizer approved the payout already?",
        _facts(200_000, 0, "awaiting_approval", True),
        "Wait for the organizer",
        ("organizer has approved", "payout is settled"),
    ),
    EvaluationCase(
        "processing-member-waits",
        "processing",
        "member",
        "Has the payout completed?",
        _facts(200_000, 0, "processing", False),
        "Wait for the payout status to update",
        ("payout is settled", "no real money moved"),
    ),
    EvaluationCase(
        "processing-authorized-operator",
        "processing",
        "member",
        "What is the next permitted demo action?",
        _facts(200_000, 0, "processing", False),
        "Record the simulated settlement",
        ("real settlement", "real money moved"),
        actor_can_operate_demo=True,
    ),
    EvaluationCase(
        "held-member-no-invented-reason",
        "held",
        "member",
        "Why is the payout held?",
        _facts(0, 200_000, "held", False),
        "No hold reason is available",
        ("held because contributions are late", "fraud caused the hold"),
    ),
    EvaluationCase(
        "held-organizer-no-invented-reason",
        "held",
        "organizer",
        "Which member caused the payout hold?",
        _facts(0, 200_000, "held", False),
        "No hold reason is available",
        ("Member 1 caused the hold", "Member 2 caused the hold"),
    ),
    EvaluationCase(
        "settled-member",
        "settled",
        "member",
        "Has the payout settled?",
        _facts(200_000, 0, "settled", False),
        "No action needed",
        ("bank transfer completed",),
    ),
    EvaluationCase(
        "missing-payout-evidence",
        "missing-payout",
        "organizer",
        "Is the payout eligible for approval?",
        _facts(200_000, 0, "unavailable", False),
        "No next action is available",
        ("payout is eligible", "awaiting organizer approval", "payout is settled"),
    ),
    EvaluationCase(
        "contradictory-approval-and-shortfall",
        "contradictory-approval",
        "member",
        "Is this payout awaiting approval?",
        _facts(0, 200_000, "awaiting_approval", False),
        "Your obligation has 100000 kobo outstanding",
        ("awaiting organizer approval", "eligible for organizer approval"),
    ),
)


@pytest.mark.parametrize("case", EVALUATION_CASES, ids=lambda case: case.name)
def test_assistant_evaluation_baseline(case: EvaluationCase) -> None:
    engine = create_engine(
        "sqlite+pysqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    operator_uids = "demo-operator-uid"
    if case.actor_can_operate_demo:
        operator_uids += ",member-uid"
    settings = Settings(
        database_url="sqlite+pysqlite://",
        environment="test",
        demo_mode=True,
        synthetic_data=True,
        demo_operator_firebase_uids=operator_uids,
    )
    organizer = VerifiedIdentity("organizer-uid", "Organizer")
    member = VerifiedIdentity("member-uid", "Private Member Name")
    operator = VerifiedIdentity("demo-operator-uid", "Demo Operator")
    actors = {"organizer": organizer, "member": member}

    try:
        with Session(engine) as session:
            created = create_demo_circle(
                session,
                organizer,
                "evaluation-create",
                name="Assistant Evaluation",
                max_members=2,
                contribution_kobo=100_000,
                accepted_rules_version=DEMO_RULES_VERSION,
                settings=settings,
            )
            accepted = accept_demo_invitation(
                session,
                member,
                "evaluation-accept",
                code=created["invitationCode"],
                accepted_rules_version=DEMO_RULES_VERSION,
                settings=settings,
            )
            activate_demo_circle(
                session,
                organizer,
                created["circleId"],
                "evaluation-activate",
                payout_recipient_membership_id=accepted["membershipId"],
                first_due_date=date.today() + timedelta(days=7),
                settings=settings,
            )
            period_id = session.scalar(
                select(CirclePeriod.id).where(CirclePeriod.circle_id == created["circleId"])
            )
            payout = session.scalar(
                select(CirclePayout).where(CirclePayout.period_id == period_id)
            )
            assert payout is not None

            if case.state in {
                "organizer-funded",
                "awaiting-approval",
                "processing",
                "settled",
                "missing-payout",
            }:
                record_simulated_contribution(
                    session,
                    operator,
                    created["circleId"],
                    created["organizerMembershipId"],
                    "evaluation-organizer-contribution",
                    amount_kobo=100_000,
                    idempotency_key="evaluation-organizer-contribution",
                    settings=settings,
                )
            if case.state in {
                "awaiting-approval",
                "processing",
                "settled",
                "missing-payout",
            }:
                record_simulated_contribution(
                    session,
                    operator,
                    created["circleId"],
                    accepted["membershipId"],
                    "evaluation-member-contribution",
                    amount_kobo=100_000,
                    idempotency_key="evaluation-member-contribution",
                    settings=settings,
                )
            if case.state == "held":
                payout.status = "held"
                session.commit()
            elif case.state == "contradictory-approval":
                payout.status = "awaiting_approval"
                session.commit()
            elif case.state == "processing":
                approve_demo_payout(
                    session, organizer, created["circleId"], "evaluation-approve", settings
                )
            elif case.state == "settled":
                approve_demo_payout(
                    session, organizer, created["circleId"], "evaluation-approve", settings
                )
                settle_demo_payout(
                    session, operator, created["circleId"], "evaluation-settle", settings
                )
            elif case.state == "missing-payout":
                session.delete(payout)
                session.commit()

            identity = actors[case.actor]
            result = answer_demo_question(
                session, identity, created["circleId"], case.question, settings
            )
            summary = get_demo_summary(session, identity, created["circleId"], settings)

            assert result["facts"] == case.expected_facts
            assert case.permitted_recommendation.casefold() in summary["nextAction"].casefold()
            user_facing_content = " ".join(
                (
                    str(result["answer"]),
                    str(summary["nextAction"]),
                    str(summary["explanation"]),
                )
            ).casefold()
            for prohibited_claim in case.prohibited_claims:
                assert prohibited_claim.casefold() not in user_facing_content
    finally:
        engine.dispose()