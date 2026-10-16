from uuid import uuid4

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    Time,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class Circle(Base):
    __tablename__ = "circles"
    __table_args__ = (
        CheckConstraint(
            "status IN ('draft', 'inviting', 'active', 'completed')",
            name="status",
        ),
        CheckConstraint(
            "frequency IS NULL OR frequency = 'weekly'",
            name="frequency",
        ),
        CheckConstraint("max_members IS NULL OR max_members > 0", name="max_members"),
        CheckConstraint(
            "contribution_kobo IS NULL OR contribution_kobo > 0",
            name="contribution_kobo",
        ),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    name: Mapped[str] = mapped_column(String(160), nullable=False)
    status: Mapped[str] = mapped_column(String(16), nullable=False, default="draft")
    synthetic: Mapped[bool] = mapped_column(default=False, nullable=False)
    max_members: Mapped[int | None] = mapped_column(Integer)
    contribution_kobo: Mapped[int | None] = mapped_column(Integer)
    frequency: Mapped[str | None] = mapped_column(String(16))
    due_time_local: Mapped[Time | None] = mapped_column(Time)
    current_rules_version: Mapped[str | None] = mapped_column(String(128))
    activated_at: Mapped[DateTime | None] = mapped_column(DateTime(timezone=True))
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


class CircleInvitation(Base):
    __tablename__ = "circle_invitations"
    __table_args__ = (
        CheckConstraint("max_uses > 0", name="max_uses"),
        CheckConstraint("uses >= 0 AND uses <= max_uses", name="uses"),
        Index("ix_circle_invitations_circle_id", "circle_id"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    circle_id: Mapped[str] = mapped_column(
        ForeignKey("circles.id", ondelete="RESTRICT"), nullable=False
    )
    token_hash: Mapped[str] = mapped_column(String(64), nullable=False, unique=True)
    created_by_user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
    )
    max_uses: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    uses: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    expires_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), nullable=False)
    revoked_at: Mapped[DateTime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class CirclePeriod(Base):
    __tablename__ = "circle_periods"
    __table_args__ = (
        UniqueConstraint("circle_id", "period_number", name="uq_circle_period_number"),
        CheckConstraint("period_number > 0", name="period_number"),
        CheckConstraint("status IN ('open', 'completed')", name="status"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    circle_id: Mapped[str] = mapped_column(
        ForeignKey("circles.id", ondelete="RESTRICT"), nullable=False
    )
    period_number: Mapped[int] = mapped_column(Integer, nullable=False)
    due_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), nullable=False)
    grace_deadline_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), nullable=False)
    status: Mapped[str] = mapped_column(String(16), nullable=False, default="open")
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class CircleObligation(Base):
    __tablename__ = "circle_obligations"
    __table_args__ = (
        UniqueConstraint("period_id", "membership_id", name="uq_obligation_period_membership"),
        CheckConstraint("amount_kobo > 0", name="amount_kobo"),
        Index("ix_circle_obligations_membership_id", "membership_id"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    period_id: Mapped[str] = mapped_column(
        ForeignKey("circle_periods.id", ondelete="RESTRICT"), nullable=False
    )
    membership_id: Mapped[str] = mapped_column(
        ForeignKey("memberships.id", ondelete="RESTRICT"), nullable=False
    )
    amount_kobo: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class SimulatedContribution(Base):
    __tablename__ = "simulated_contributions"
    __table_args__ = (
        CheckConstraint("amount_kobo > 0", name="amount_kobo"),
        CheckConstraint("mode = 'simulated'", name="mode"),
        UniqueConstraint(
            "circle_id", "actor_user_id", "idempotency_key", name="uq_sim_contribution_idempotency"
        ),
        Index("ix_simulated_contributions_obligation_id", "obligation_id"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    circle_id: Mapped[str] = mapped_column(
        ForeignKey("circles.id", ondelete="RESTRICT"), nullable=False
    )
    obligation_id: Mapped[str] = mapped_column(
        ForeignKey("circle_obligations.id", ondelete="RESTRICT"), nullable=False
    )
    actor_user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
    )
    amount_kobo: Mapped[int] = mapped_column(Integer, nullable=False)
    idempotency_key: Mapped[str] = mapped_column(String(128), nullable=False)
    mode: Mapped[str] = mapped_column(String(16), nullable=False, default="simulated")
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class CirclePayout(Base):
    __tablename__ = "circle_payouts"
    __table_args__ = (
        UniqueConstraint("period_id", name="uq_circle_payout_period"),
        CheckConstraint("amount_kobo > 0", name="amount_kobo"),
        CheckConstraint(
            "status IN ('scheduled', 'held', 'awaiting_approval', 'processing', 'settled')",
            name="status",
        ),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    period_id: Mapped[str] = mapped_column(
        ForeignKey("circle_periods.id", ondelete="RESTRICT"), nullable=False
    )
    recipient_membership_id: Mapped[str] = mapped_column(
        ForeignKey("memberships.id", ondelete="RESTRICT"), nullable=False
    )
    amount_kobo: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[str] = mapped_column(String(24), nullable=False, default="scheduled")
    approved_by_user_id: Mapped[str | None] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT")
    )
    approved_at: Mapped[DateTime | None] = mapped_column(DateTime(timezone=True))
    settled_at: Mapped[DateTime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class CirclePayoutEvent(Base):
    __tablename__ = "circle_payout_events"
    __table_args__ = (
        CheckConstraint("action IN ('approved', 'simulated_settled')", name="action"),
        UniqueConstraint("payout_id", "action", name="uq_circle_payout_event_action"),
        Index("ix_circle_payout_events_payout_id", "payout_id"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    payout_id: Mapped[str] = mapped_column(
        ForeignKey("circle_payouts.id", ondelete="RESTRICT"), nullable=False
    )
    actor_user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
    )
    action: Mapped[str] = mapped_column(String(24), nullable=False)
    reference: Mapped[str | None] = mapped_column(String(128))
    request_id: Mapped[str] = mapped_column(String(36), nullable=False)
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
