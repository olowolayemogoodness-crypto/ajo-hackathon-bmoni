from datetime import UTC, date, datetime, time, timedelta
from hashlib import sha256
from secrets import token_hex
from zoneinfo import ZoneInfo

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.auth.identity import VerifiedIdentity
from app.core.config import Settings
from app.core.demo_rules import DEMO_RULES_VERSION, load_demo_rules
from app.modules.circles.models import (
    Circle,
    CircleInvitation,
    CircleObligation,
    CirclePayout,
    CirclePayoutEvent,
    CirclePeriod,
    Membership,
    MembershipEvent,
    SimulatedContribution,
)
from app.modules.users.models import User
from app.modules.users.repository import resolve_user

LAGOS = ZoneInfo("Africa/Lagos")
INVITATION_TTL = timedelta(days=7)


def _require_demo(settings: Settings) -> None:
    if not settings.demo_mode or not settings.synthetic_data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    load_demo_rules()


def _require_demo_operator(identity: VerifiedIdentity, settings: Settings) -> None:
    _require_demo(settings)
    if identity.firebase_uid not in settings.demo_operator_uids:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN)


def _resolve_actor_id(session: Session, identity: VerifiedIdentity) -> str:
    actor = resolve_user(session, VerifiedIdentity(identity.firebase_uid, None))
    actor_id = actor.id
    session.rollback()
    return actor_id


def _hash_invitation(code: str) -> str:
    return sha256(code.strip().upper().encode("utf-8")).hexdigest()


def _new_invitation_code() -> str:
    return f"AJO-{token_hex(16).upper()}"


def get_demo_rules(settings: Settings) -> dict[str, str]:
    _require_demo(settings)
    return {"version": DEMO_RULES_VERSION, "text": load_demo_rules()}


def _lock_circle(session: Session, circle_id: str) -> Circle:
    circle = session.scalar(select(Circle).where(Circle.id == circle_id).with_for_update())
    if circle is None or not circle.synthetic:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    return circle


def create_demo_circle(
    session: Session,
    identity: VerifiedIdentity,
    request_id: str,
    *,
    name: str,
    max_members: int,
    contribution_kobo: int,
    accepted_rules_version: str,
    settings: Settings,
) -> dict[str, object]:
    _require_demo(settings)
    if accepted_rules_version != DEMO_RULES_VERSION:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT)
    actor_id = _resolve_actor_id(session, identity)
    invite_code = _new_invitation_code()
    now = datetime.now(UTC)
    expires_at = now + INVITATION_TTL

    with session.begin():
        circle = Circle(
            name=name.strip(),
            status="inviting",
            synthetic=True,
            max_members=max_members,
            contribution_kobo=contribution_kobo,
            frequency="weekly",
            due_time_local=time(9, 0),
            current_rules_version=DEMO_RULES_VERSION,
        )
        session.add(circle)
        session.flush()

        organizer = Membership(
            circle_id=circle.id,
            user_id=actor_id,
            role="organizer",
            status="active",
        )
        session.add(organizer)
        session.flush()
        session.add(
            MembershipEvent(
                circle_id=circle.id,
                membership_id=organizer.id,
                user_id=actor_id,
                actor_user_id=actor_id,
                action="membership_created",
                previous_status=None,
                resulting_status="active",
                previous_role=None,
                resulting_role="organizer",
                accepted_rules_version=DEMO_RULES_VERSION,
                request_id=request_id,
            )
        )
        session.add(
            CircleInvitation(
                circle_id=circle.id,
                token_hash=_hash_invitation(invite_code),
                created_by_user_id=actor_id,
                max_uses=1,
                uses=0,
                expires_at=expires_at,
            )
        )
        session.flush()
        result = {
            "circleId": circle.id,
            "name": circle.name,
            "status": circle.status,
            "maxMembers": circle.max_members,
            "contributionKobo": circle.contribution_kobo,
            "frequency": circle.frequency,
            "dueTimeLocal": "09:00",
            "rulesVersion": circle.current_rules_version,
            "organizerMembershipId": organizer.id,
            "invitationCode": invite_code,
            "invitationExpiresAt": expires_at.isoformat(),
            "requestId": request_id,
        }
    return result


def inspect_demo_invitation(
    session: Session,
    code: str,
    settings: Settings,
) -> dict[str, object]:
    _require_demo(settings)
    invitation = session.scalar(
        select(CircleInvitation).where(CircleInvitation.token_hash == _hash_invitation(code))
    )
    if invitation is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    circle = session.get(Circle, invitation.circle_id)
    now = datetime.now(UTC)
    if (
        circle is None
        or not circle.synthetic
        or circle.status != "inviting"
        or invitation.revoked_at is not None
        or _as_utc(invitation.expires_at) <= now
        or invitation.uses >= invitation.max_uses
    ):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    return {
        "circleId": circle.id,
        "name": circle.name,
        "contributionKobo": circle.contribution_kobo,
        "maxMembers": circle.max_members,
        "activeMemberCount": _active_member_count(session, circle.id),
        "frequency": circle.frequency,
        "dueTimeLocal": "09:00",
        "rulesVersion": circle.current_rules_version,
        "rulesText": load_demo_rules(),
        "invitationExpiresAt": _as_utc(invitation.expires_at).isoformat(),
    }


def accept_demo_invitation(
    session: Session,
    identity: VerifiedIdentity,
    request_id: str,
    *,
    code: str,
    accepted_rules_version: str,
    settings: Settings,
) -> dict[str, object]:
    _require_demo(settings)
    actor_id = _resolve_actor_id(session, identity)
    invitation_id = session.scalar(
        select(CircleInvitation.id).where(CircleInvitation.token_hash == _hash_invitation(code))
    )
    if invitation_id is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    session.rollback()

    with session.begin():
        invitation_circle_id = session.scalar(
            select(CircleInvitation.circle_id).where(CircleInvitation.id == invitation_id)
        )
        if invitation_circle_id is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
        circle = _lock_circle(session, invitation_circle_id)
        invitation = session.scalar(
            select(CircleInvitation).where(CircleInvitation.id == invitation_id).with_for_update()
        )
        if invitation is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
        now = datetime.now(UTC)
        if (
            circle.status != "inviting"
            or invitation.revoked_at is not None
            or _as_utc(invitation.expires_at) <= now
            or invitation.uses >= invitation.max_uses
        ):
            raise HTTPException(status_code=status.HTTP_409_CONFLICT)
        if (
            circle.current_rules_version != DEMO_RULES_VERSION
            or accepted_rules_version != circle.current_rules_version
        ):
            raise HTTPException(status_code=status.HTTP_409_CONFLICT)
        if _active_member_count(session, circle.id) >= (circle.max_members or 0):
            raise HTTPException(status_code=status.HTTP_409_CONFLICT)

        membership = session.scalar(
            select(Membership)
            .where(Membership.circle_id == circle.id, Membership.user_id == actor_id)
            .with_for_update()
        )
        if membership is not None and membership.status == "active":
            raise HTTPException(status_code=status.HTTP_409_CONFLICT)

        if membership is None:
            membership = Membership(
                circle_id=circle.id,
                user_id=actor_id,
                role="member",
                status="active",
            )
            session.add(membership)
            action = "membership_created"
            previous_status = None
            previous_role = None
        else:
            previous_status = membership.status
            previous_role = membership.role
            membership.status = "active"
            membership.role = "member"
            action = "membership_rejoined"
        session.flush()

        invitation.uses += 1
        session.add(
            MembershipEvent(
                circle_id=circle.id,
                membership_id=membership.id,
                user_id=actor_id,
                actor_user_id=actor_id,
                action=action,
                previous_status=previous_status,
                resulting_status="active",
                previous_role=previous_role,
                resulting_role="member",
                invitation_id=invitation.id,
                accepted_rules_version=accepted_rules_version,
                request_id=request_id,
            )
        )
        session.flush()
        result = {
            "membershipId": membership.id,
            "circleId": circle.id,
            "status": membership.status,
            "role": membership.role,
            "acceptedRulesVersion": accepted_rules_version,
            "joinedAt": now.isoformat(),
            "requestId": request_id,
        }
    return result


def activate_demo_circle(
    session: Session,
    identity: VerifiedIdentity,
    circle_id: str,
    request_id: str,
    *,
    payout_recipient_membership_id: str,
    first_due_date: date,
    settings: Settings,
) -> dict[str, object]:
    _require_demo(settings)
    actor_id = _resolve_actor_id(session, identity)
    due_at = datetime.combine(first_due_date, time(9, 0), tzinfo=LAGOS).astimezone(UTC)
    now = datetime.now(UTC)
    if due_at <= now:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY)

    with session.begin():
        circle = _lock_circle(session, circle_id)
        organizer = _active_membership_for_user(session, circle.id, actor_id)
        if organizer is None or organizer.role != "organizer":
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN)
        if circle.status != "inviting" or circle.current_rules_version != DEMO_RULES_VERSION:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT)
        members = session.scalars(
            select(Membership)
            .where(Membership.circle_id == circle.id, Membership.status == "active")
            .order_by(Membership.id)
            .with_for_update()
        ).all()
        if len(members) < 2 or len(members) > (circle.max_members or 0):
            raise HTTPException(status_code=status.HTTP_409_CONFLICT)
        recipient = next(
            (member for member in members if member.id == payout_recipient_membership_id), None
        )
        if recipient is None or recipient.role != "member":
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY)

        period = CirclePeriod(
            circle_id=circle.id,
            period_number=1,
            due_at=due_at,
            grace_deadline_at=due_at + timedelta(hours=24),
            status="open",
        )
        session.add(period)
        session.flush()
        obligations = [
            CircleObligation(
                period_id=period.id,
                membership_id=member.id,
                amount_kobo=circle.contribution_kobo,
            )
            for member in members
        ]
        session.add_all(obligations)
        payout = CirclePayout(
            period_id=period.id,
            recipient_membership_id=recipient.id,
            amount_kobo=circle.contribution_kobo * len(members),
            status="scheduled",
        )
        session.add(payout)
        circle.status = "active"
        circle.activated_at = now
        session.flush()
        result = {
            "circleId": circle.id,
            "status": circle.status,
            "periodId": period.id,
            "periodNumber": period.period_number,
            "dueAt": due_at.isoformat(),
            "graceDeadlineAt": period.grace_deadline_at.isoformat(),
            "payoutId": payout.id,
            "recipientMembershipId": recipient.id,
            "payoutAmountKobo": payout.amount_kobo,
            "requestId": request_id,
        }
    return result


def get_demo_summary(
    session: Session,
    identity: VerifiedIdentity,
    circle_id: str,
    settings: Settings,
) -> dict[str, object]:
    _require_demo(settings)
    actor_id = _resolve_actor_id(session, identity)
    circle = session.get(Circle, circle_id)
    current_membership = _active_membership_for_user(session, circle_id, actor_id)
    if circle is None or not circle.synthetic or current_membership is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    period = session.scalar(
        select(CirclePeriod)
        .where(CirclePeriod.circle_id == circle.id)
        .order_by(CirclePeriod.period_number)
    )
    if period is None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT)

    rows = session.execute(
        select(CircleObligation, Membership, User)
        .join(Membership, Membership.id == CircleObligation.membership_id)
        .join(User, User.id == Membership.user_id)
        .where(CircleObligation.period_id == period.id)
        .order_by(Membership.created_at, Membership.id)
    ).all()
    obligation_ids = [obligation.id for obligation, _, _ in rows]
    totals = (
        dict(
            session.execute(
                select(
                    SimulatedContribution.obligation_id,
                    func.coalesce(func.sum(SimulatedContribution.amount_kobo), 0),
                )
                .where(SimulatedContribution.obligation_id.in_(obligation_ids))
                .group_by(SimulatedContribution.obligation_id)
            ).all()
        )
        if obligation_ids
        else {}
    )
    obligations = []
    collected = 0
    shortfall = 0
    for obligation, membership, _user in rows:
        paid = int(totals.get(obligation.id, 0))
        remaining = max(0, obligation.amount_kobo - paid)
        collected += paid
        shortfall += remaining
        obligations.append(
            {
                "membershipId": membership.id,
                "memberLabel": f"Member {len(obligations) + 1}",
                "amountKobo": obligation.amount_kobo,
                "paidKobo": paid,
                "remainingKobo": remaining,
                "fullyFunded": remaining == 0,
            }
        )
    payout = session.scalar(select(CirclePayout).where(CirclePayout.period_id == period.id))
    recipient = session.get(Membership, payout.recipient_membership_id) if payout else None
    recipient_label = next(
        (
            obligation["memberLabel"]
            for obligation in obligations
            if recipient is not None and obligation["membershipId"] == recipient.id
        ),
        "Member" if recipient else None,
    )
    fully_funded = bool(obligations) and shortfall == 0
    eligible = fully_funded and payout is not None and payout.status == "awaiting_approval"
    if payout is not None and payout.status == "settled":
        explanation = (
            f"All {len(obligations)} obligations were funded. The simulated payout "
            f"of {payout.amount_kobo} kobo is settled. No real money moved."
        )
    elif payout is not None and payout.status == "held":
        explanation = (
            "The payout is currently on hold. The backend summary does not provide a "
            "separate hold reason."
        )
    elif payout is not None and payout.status == "processing":
        explanation = (
            f"All {len(obligations)} obligations are funded. The payout is in the "
            "processing stage and is awaiting explicit simulated settlement."
        )
    elif eligible:
        payout_amount = payout.amount_kobo if payout else 0
        explanation = (
            f"All {len(obligations)} member obligations are fully funded. "
            f"The simulated payout of {payout_amount} kobo is eligible for "
            "organizer approval."
        )
    else:
        funded_count = sum(1 for obligation in obligations if obligation["fullyFunded"])
        explanation = (
            f"{funded_count} of {len(obligations)} obligations are fully funded; "
            f"{shortfall} kobo remains outstanding. "
            "The payout is not eligible yet."
        )
    return {
        "circle": {
            "circleId": circle.id,
            "name": circle.name,
            "status": circle.status,
            "frequency": circle.frequency,
            "contributionKobo": circle.contribution_kobo,
            "maxMembers": circle.max_members,
            "rulesVersion": circle.current_rules_version,
        },
        "currentRole": current_membership.role,
        "period": {
            "periodId": period.id,
            "periodNumber": period.period_number,
            "dueAt": _as_utc(period.due_at).isoformat(),
            "graceDeadlineAt": _as_utc(period.grace_deadline_at).isoformat(),
        },
        "obligations": obligations,
        "collectedKobo": collected,
        "shortfallKobo": shortfall,
        "fullyFunded": fully_funded,
        "payout": {
            "payoutId": payout.id if payout else None,
            "amountKobo": payout.amount_kobo if payout else 0,
            "status": payout.status if payout else "unavailable",
            "eligible": eligible,
            "recipientMembershipId": recipient.id if recipient else None,
            "recipientLabel": recipient_label,
        },
        "explanation": explanation,
        "canOperateDemo": identity.firebase_uid in settings.demo_operator_uids,
    }


def answer_demo_question(
    session: Session,
    identity: VerifiedIdentity,
    circle_id: str,
    question: str,
    settings: Settings,
) -> dict[str, object]:
    summary = get_demo_summary(session, identity, circle_id, settings)
    normalized = question.casefold()
    obligations = summary["obligations"]
    payout = summary["payout"]
    payout_status = str(payout["status"])
    shortfall = int(summary["shortfallKobo"])

    if payout_status == "settled":
        answer = "The payout is already settled. No real money moved."
    elif payout_status == "held":
        answer = (
            "The payout is on hold. The backend summary does not provide a separate "
            "hold reason."
        )
    elif payout_status == "processing":
        answer = (
            "The payout is in the processing stage and is awaiting explicit "
            "simulated settlement."
        )
    elif payout_status == "awaiting_approval":
        answer = "The payout is awaiting organizer approval."
    elif shortfall > 0:
        outstanding = [item for item in obligations if item["remainingKobo"] > 0]
        if not outstanding:
            answer = "No contribution shortfall remains for this demo period."
        else:
            members = ", ".join(
                f"{item['memberLabel']}: {item['remainingKobo']} kobo"
                for item in outstanding
            )
            answer = f"{shortfall} kobo remains outstanding ({members})."
    elif any(term in normalized for term in ("eligible", "approval", "payout", "receive")):
        if payout["eligible"]:
            answer = (
                f"The payout to {payout['recipientLabel']} is eligible and "
                "awaits organizer approval."
            )
        else:
            answer = (
                "The backend summary does not provide enough information to explain the "
                "current payout state."
            )
    elif any(term in normalized for term in ("shortfall", "owe", "missing", "left to pay")):
        outstanding = [item for item in obligations if item["remainingKobo"] > 0]
        if not outstanding:
            answer = "No contribution shortfall remains for this demo period."
        else:
            members = ", ".join(
                f"{item['memberLabel']}: {item['remainingKobo']} kobo"
                for item in outstanding
            )
            answer = f"{shortfall} kobo remains outstanding ({members})."
    else:
        answer = summary["explanation"]

    return {
        "answer": answer,
        "facts": {
            "collectedKobo": summary["collectedKobo"],
            "shortfallKobo": summary["shortfallKobo"],
            "payoutStatus": payout["status"],
            "payoutEligible": payout["eligible"],
            "mode": "simulated",
        },
    }


def get_demo_setup(
    session: Session,
    identity: VerifiedIdentity,
    circle_id: str,
    settings: Settings,
) -> dict[str, object]:
    _require_demo(settings)
    actor_id = _resolve_actor_id(session, identity)
    circle = session.get(Circle, circle_id)
    if circle is None or not circle.synthetic:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    organizer = _active_membership_for_user(session, circle_id, actor_id)
    if organizer is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    can_manage = organizer.role == "organizer"
    members = session.scalars(
        select(Membership)
        .where(Membership.circle_id == circle.id, Membership.status == "active")
        .order_by(Membership.created_at, Membership.id)
    ).all()
    return {
        "circleId": circle.id,
        "name": circle.name,
        "status": circle.status,
        "maxMembers": circle.max_members,
        "contributionKobo": circle.contribution_kobo,
        "frequency": circle.frequency,
        "dueTimeLocal": "09:00",
        "rulesVersion": circle.current_rules_version,
        "currentRole": organizer.role,
        "canManageCircle": can_manage,
        "canOperateDemo": identity.firebase_uid in settings.demo_operator_uids,
        "members": [
            {
                "membershipId": member.id,
                "role": member.role,
                "label": "Organizer" if member.role == "organizer" else f"Member {index}",
            }
            for index, member in enumerate(members, start=1)
        ],
    }


def record_simulated_contribution(
    session: Session,
    identity: VerifiedIdentity,
    circle_id: str,
    membership_id: str,
    request_id: str,
    *,
    amount_kobo: int,
    idempotency_key: str,
    settings: Settings,
) -> dict[str, object]:
    _require_demo_operator(identity, settings)
    actor_id = _resolve_actor_id(session, identity)
    with session.begin():
        circle = _lock_circle(session, circle_id)
        prior = session.scalar(
            select(SimulatedContribution).where(
                SimulatedContribution.circle_id == circle.id,
                SimulatedContribution.actor_user_id == actor_id,
                SimulatedContribution.idempotency_key == idempotency_key,
            )
        )
        if prior is not None:
            prior_matches = session.scalar(
                select(CircleObligation.id).where(
                    CircleObligation.id == prior.obligation_id,
                    CircleObligation.membership_id == membership_id,
                )
            )
            if prior_matches is None or prior.amount_kobo != amount_kobo:
                raise HTTPException(status_code=status.HTTP_409_CONFLICT)
            return {
                "contributionId": prior.id,
                "obligationId": prior.obligation_id,
                "amountKobo": prior.amount_kobo,
                "mode": prior.mode,
                "idempotentReplay": True,
                "requestId": request_id,
            }
        if circle.status != "active":
            raise HTTPException(status_code=status.HTTP_409_CONFLICT)
        period = session.scalar(
            select(CirclePeriod)
            .where(CirclePeriod.circle_id == circle.id, CirclePeriod.period_number == 1)
            .with_for_update()
        )
        if period is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
        obligation = session.scalar(
            select(CircleObligation)
            .where(
                CircleObligation.period_id == period.id,
                CircleObligation.membership_id == membership_id,
            )
            .with_for_update()
        )
        if obligation is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
        paid = session.scalar(
            select(func.coalesce(func.sum(SimulatedContribution.amount_kobo), 0)).where(
                SimulatedContribution.obligation_id == obligation.id
            )
        )
        remaining = obligation.amount_kobo - int(paid)
        if amount_kobo <= 0 or amount_kobo > remaining:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY)
        event = SimulatedContribution(
            circle_id=circle.id,
            obligation_id=obligation.id,
            actor_user_id=actor_id,
            amount_kobo=amount_kobo,
            idempotency_key=idempotency_key,
            mode="simulated",
        )
        session.add(event)
        session.flush()
        _refresh_payout_status(session, period)
        result = {
            "contributionId": event.id,
            "obligationId": obligation.id,
            "amountKobo": event.amount_kobo,
            "mode": event.mode,
            "idempotentReplay": False,
            "requestId": request_id,
        }
    return result


def approve_demo_payout(
    session: Session,
    identity: VerifiedIdentity,
    circle_id: str,
    request_id: str,
    settings: Settings,
) -> dict[str, object]:
    _require_demo(settings)
    actor_id = _resolve_actor_id(session, identity)
    with session.begin():
        circle = _lock_circle(session, circle_id)
        organizer = _active_membership_for_user(session, circle.id, actor_id, lock=True)
        if organizer is None or organizer.role != "organizer":
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN)
        period = session.scalar(
            select(CirclePeriod)
            .where(CirclePeriod.circle_id == circle.id, CirclePeriod.period_number == 1)
            .with_for_update()
        )
        payout = (
            session.scalar(
                select(CirclePayout).where(CirclePayout.period_id == period.id).with_for_update()
            )
            if period
            else None
        )
        if payout is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
        if payout.approved_by_user_id is not None or payout.status == "settled":
            raise HTTPException(status_code=status.HTTP_409_CONFLICT)
        recipient = session.get(Membership, payout.recipient_membership_id)
        if recipient is None or recipient.user_id == actor_id or recipient.role == "organizer":
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN)
        if not _period_is_fully_funded(session, period.id):
            _refresh_payout_status(session, period)
            raise HTTPException(status_code=status.HTTP_409_CONFLICT)

        now = datetime.now(UTC)
        payout.status = "processing"
        payout.approved_by_user_id = actor_id
        payout.approved_at = now
        event = CirclePayoutEvent(
            payout_id=payout.id,
            actor_user_id=actor_id,
            action="approved",
            request_id=request_id,
        )
        session.add(event)
        session.flush()
        result = {
            "payoutId": payout.id,
            "status": payout.status,
            "approvedBy": actor_id,
            "mode": "simulated",
            "requestId": request_id,
        }
    return result


def settle_demo_payout(
    session: Session,
    identity: VerifiedIdentity,
    circle_id: str,
    request_id: str,
    settings: Settings,
) -> dict[str, object]:
    _require_demo_operator(identity, settings)
    actor_id = _resolve_actor_id(session, identity)
    with session.begin():
        circle = _lock_circle(session, circle_id)
        period = session.scalar(
            select(CirclePeriod)
            .where(CirclePeriod.circle_id == circle.id, CirclePeriod.period_number == 1)
            .with_for_update()
        )
        payout = (
            session.scalar(
                select(CirclePayout).where(CirclePayout.period_id == period.id).with_for_update()
            )
            if period
            else None
        )
        if payout is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
        existing = session.scalar(
            select(CirclePayoutEvent).where(
                CirclePayoutEvent.payout_id == payout.id,
                CirclePayoutEvent.action == "simulated_settled",
            )
        )
        if payout.status == "settled" and existing is not None:
            return {
                "payoutId": payout.id,
                "eventId": existing.id,
                "status": payout.status,
                "amountKobo": payout.amount_kobo,
                "mode": "simulated",
                "reference": existing.reference,
                "idempotentReplay": True,
                "requestId": request_id,
            }
        if payout.status != "processing" or payout.approved_by_user_id is None:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT)

        now = datetime.now(UTC)
        reference = f"AJO-DEMO-{token_hex(6).upper()}"
        payout.status = "settled"
        payout.settled_at = now
        period.status = "completed"
        circle.status = "completed"
        event = CirclePayoutEvent(
            payout_id=payout.id,
            actor_user_id=actor_id,
            action="simulated_settled",
            reference=reference,
            request_id=request_id,
        )
        session.add(event)
        session.flush()
        result = {
            "payoutId": payout.id,
            "eventId": event.id,
            "status": payout.status,
            "amountKobo": payout.amount_kobo,
            "mode": "simulated",
            "reference": reference,
            "idempotentReplay": False,
            "requestId": request_id,
        }
    return result


def _active_member_count(session: Session, circle_id: str) -> int:
    return int(
        session.scalar(
            select(func.count())
            .select_from(Membership)
            .where(
                Membership.circle_id == circle_id,
                Membership.status == "active",
            )
        )
    )


def _active_membership_for_user(
    session: Session,
    circle_id: str,
    user_id: str,
    *,
    lock: bool = False,
) -> Membership | None:
    statement = select(Membership).where(
        Membership.circle_id == circle_id,
        Membership.user_id == user_id,
        Membership.status == "active",
    )
    if lock:
        statement = statement.with_for_update()
    return session.scalar(statement)


def _period_is_fully_funded(session: Session, period_id: str) -> bool:
    obligations = session.scalars(
        select(CircleObligation).where(CircleObligation.period_id == period_id)
    ).all()
    if not obligations:
        return False
    for obligation in obligations:
        paid = session.scalar(
            select(func.coalesce(func.sum(SimulatedContribution.amount_kobo), 0)).where(
                SimulatedContribution.obligation_id == obligation.id
            )
        )
        if int(paid) < obligation.amount_kobo:
            return False
    return True


def _refresh_payout_status(session: Session, period: CirclePeriod) -> None:
    payout = session.scalar(
        select(CirclePayout).where(CirclePayout.period_id == period.id).with_for_update()
    )
    if payout is None or payout.status in {"processing", "settled"}:
        return
    if _period_is_fully_funded(session, period.id):
        payout.status = "awaiting_approval"
    elif datetime.now(UTC) > _as_utc(period.grace_deadline_at):
        payout.status = "held"
    else:
        payout.status = "scheduled"


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)
