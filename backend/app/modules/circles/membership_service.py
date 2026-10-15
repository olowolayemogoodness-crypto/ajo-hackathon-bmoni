from dataclasses import dataclass

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.auth.identity import VerifiedIdentity
from app.modules.circles.models import Circle, Membership, MembershipEvent
from app.modules.users.repository import resolve_user


@dataclass(frozen=True)
class MembershipActionResult:
    membership_id: str
    circle_id: str
    status: str
    role: str
    event_id: str
    request_id: str


def leave_circle(
    session: Session,
    identity: VerifiedIdentity,
    circle_id: str,
    request_id: str,
    reason: str | None,
) -> MembershipActionResult:
    actor = resolve_user(session, identity)
    session.rollback()

    with session.begin():
        circle = _lock_circle(session, circle_id)
        membership = _lock_membership(session, circle_id, actor.id, active_only=False)
        if membership.status != "active":
            raise HTTPException(status_code=status.HTTP_409_CONFLICT)
        if membership.role == "organizer" and _active_organizer_count(session, circle_id) <= 1:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT)

        event = _change_membership(
            session,
            circle,
            membership,
            actor.id,
            "member_left",
            "inactive",
            request_id,
            reason,
        )
        result = _result(membership, event, request_id)

    return result


def revoke_membership(
    session: Session,
    identity: VerifiedIdentity,
    circle_id: str,
    membership_id: str,
    request_id: str,
    reason: str,
) -> MembershipActionResult:
    actor = resolve_user(session, identity)
    session.rollback()

    with session.begin():
        circle = _lock_circle(session, circle_id)
        actor_membership = _lock_membership(session, circle_id, actor.id)
        if actor_membership.role != "organizer":
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN)

        target = session.scalar(
            select(Membership)
            .where(Membership.id == membership_id, Membership.circle_id == circle_id)
            .with_for_update()
        )
        if target is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
        if target.status != "active":
            raise HTTPException(status_code=status.HTTP_409_CONFLICT)
        if target.user_id == actor.id:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT)
        if target.role == "organizer" and _active_organizer_count(session, circle_id) <= 1:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT)

        event = _change_membership(
            session,
            circle,
            target,
            actor.id,
            "member_revoked",
            "revoked",
            request_id,
            reason,
        )
        result = _result(target, event, request_id)

    return result


def promote_organizer(
    session: Session,
    identity: VerifiedIdentity,
    circle_id: str,
    membership_id: str,
    request_id: str,
) -> MembershipActionResult:
    actor = resolve_user(session, identity)
    session.rollback()

    with session.begin():
        circle = _lock_circle(session, circle_id)
        actor_membership = _lock_membership(session, circle_id, actor.id)
        if actor_membership.role != "organizer":
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN)

        target = session.scalar(
            select(Membership)
            .where(Membership.id == membership_id, Membership.circle_id == circle_id)
            .with_for_update()
        )
        if target is None or target.status != "active":
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
        if target.role == "organizer":
            raise HTTPException(status_code=status.HTTP_409_CONFLICT)

        event = MembershipEvent(
            circle_id=circle.id,
            membership_id=target.id,
            user_id=target.user_id,
            actor_user_id=actor.id,
            action="organizer_promoted",
            previous_status=target.status,
            resulting_status=target.status,
            previous_role=target.role,
            resulting_role="organizer",
            request_id=request_id,
        )
        target.role = "organizer"
        session.add(event)
        session.flush()
        result = _result(target, event, request_id)

    return result


def _lock_circle(session: Session, circle_id: str) -> Circle:
    circle = session.scalar(select(Circle).where(Circle.id == circle_id).with_for_update())
    if circle is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    return circle


def _lock_membership(
    session: Session,
    circle_id: str,
    user_id: str,
    *,
    active_only: bool = True,
) -> Membership:
    statement = select(Membership).where(
        Membership.circle_id == circle_id,
        Membership.user_id == user_id,
    )
    if active_only:
        statement = statement.where(Membership.status == "active")
    membership = session.scalar(statement.with_for_update())
    if membership is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    return membership


def _active_organizer_count(session: Session, circle_id: str) -> int:
    return session.scalar(
        select(func.count())
        .select_from(Membership)
        .where(
            Membership.circle_id == circle_id,
            Membership.status == "active",
            Membership.role == "organizer",
        )
    )


def _change_membership(
    session: Session,
    circle: Circle,
    membership: Membership,
    actor_user_id: str,
    action: str,
    resulting_status: str,
    request_id: str,
    reason: str | None,
) -> MembershipEvent:
    event = MembershipEvent(
        circle_id=circle.id,
        membership_id=membership.id,
        user_id=membership.user_id,
        actor_user_id=actor_user_id,
        action=action,
        previous_status=membership.status,
        resulting_status=resulting_status,
        previous_role=membership.role,
        resulting_role=membership.role,
        reason=reason,
        request_id=request_id,
    )
    membership.status = resulting_status
    session.add(event)
    session.flush()
    return event


def _result(
    membership: Membership,
    event: MembershipEvent,
    request_id: str,
) -> MembershipActionResult:
    return MembershipActionResult(
        membership_id=membership.id,
        circle_id=membership.circle_id,
        status=membership.status,
        role=membership.role,
        event_id=event.id,
        request_id=request_id,
    )
