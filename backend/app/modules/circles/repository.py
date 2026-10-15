from sqlalchemy import select
from sqlalchemy.orm import Session

from app.modules.circles.models import Circle, Membership


def list_active_memberships(session: Session, user_id: str) -> list[tuple[Membership, Circle]]:
    rows = session.execute(
        select(Membership, Circle)
        .join(Circle, Circle.id == Membership.circle_id)
        .where(Membership.user_id == user_id, Membership.status == "active")
        .order_by(Circle.name, Circle.id)
    )
    return list(rows.tuples())


def get_circle_for_active_member(
    session: Session,
    user_id: str,
    circle_id: str,
) -> Circle | None:
    return session.scalar(
        select(Circle)
        .join(Membership, Membership.circle_id == Circle.id)
        .where(
            Circle.id == circle_id,
            Membership.user_id == user_id,
            Membership.status == "active",
        )
    )
