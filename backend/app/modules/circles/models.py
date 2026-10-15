from uuid import uuid4

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class Circle(Base):
    __tablename__ = "circles"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    name: Mapped[str] = mapped_column(String(160), nullable=False)
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class Membership(Base):
    __tablename__ = "memberships"
    __table_args__ = (
        UniqueConstraint("circle_id", "user_id", name="uq_memberships_circle_user"),
        CheckConstraint("role IN ('organizer', 'member')", name="role"),
        CheckConstraint("status IN ('active', 'inactive', 'revoked')", name="status"),
        Index("ix_memberships_user_id", "user_id"),
        Index("ix_memberships_circle_id", "circle_id"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    circle_id: Mapped[str] = mapped_column(
        ForeignKey("circles.id", ondelete="RESTRICT"), nullable=False
    )
    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
    )
    role: Mapped[str] = mapped_column(String(16), nullable=False)
    status: Mapped[str] = mapped_column(String(16), nullable=False, default="active")
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class MembershipEvent(Base):
    __tablename__ = "membership_events"
    __table_args__ = (
        CheckConstraint(
            "action IN ('membership_created', 'membership_rejoined', 'member_left', "
            "'member_revoked', 'organizer_promoted')",
            name="action",
        ),
        CheckConstraint(
            "previous_status IS NULL OR previous_status IN ('active', 'inactive', 'revoked')",
            name="previous_status",
        ),
        CheckConstraint(
            "resulting_status IS NULL OR resulting_status IN ('active', 'inactive', 'revoked')",
            name="resulting_status",
        ),
        CheckConstraint(
            "previous_role IS NULL OR previous_role IN ('organizer', 'member')",
            name="previous_role",
        ),
        CheckConstraint(
            "resulting_role IS NULL OR resulting_role IN ('organizer', 'member')",
            name="resulting_role",
        ),
        Index("ix_membership_events_circle_created_at", "circle_id", "created_at"),
        Index("ix_membership_events_membership_id", "membership_id"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    circle_id: Mapped[str] = mapped_column(
        ForeignKey("circles.id", ondelete="RESTRICT"), nullable=False
    )
    membership_id: Mapped[str] = mapped_column(
        ForeignKey("memberships.id", ondelete="RESTRICT"), nullable=False
    )
    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
    )
    actor_user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
    )
    action: Mapped[str] = mapped_column(String(32), nullable=False)
    previous_status: Mapped[str | None] = mapped_column(String(16))
    resulting_status: Mapped[str | None] = mapped_column(String(16))
    previous_role: Mapped[str | None] = mapped_column(String(16))
    resulting_role: Mapped[str | None] = mapped_column(String(16))
    invitation_id: Mapped[str | None] = mapped_column(String(36))
    accepted_rules_version: Mapped[str | None] = mapped_column(String(128))
    reason: Mapped[str | None] = mapped_column(String(500))
    request_id: Mapped[str] = mapped_column(String(36), nullable=False)
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
