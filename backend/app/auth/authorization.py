from typing import Literal

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.modules.circles.models import Membership

CircleRole = Literal["organizer", "member"]


def require_active_membership(session: Session, user_id: str, circle_id: str) -> Membership:
    membership = session.scalar(
        select(Membership).where(
            Membership.circle_id == circle_id,
            Membership.user_id == user_id,
            Membership.status == "active",
        )
    )
    if membership is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    return membership


def require_circle_role(
    session: Session,
    user_id: str,
    circle_id: str,
    required_role: CircleRole,
) -> Membership:
    membership = require_active_membership(session, user_id, circle_id)
    if membership.role != required_role:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN)
    return membership
