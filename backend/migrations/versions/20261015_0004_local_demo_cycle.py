"""Add the local synthetic one-period circle cycle.

Revision ID: 20261015_0004
Revises: 20261015_0003
Create Date: 2026-10-15
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20261015_0004"
down_revision: str | None = "20261015_0003"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    with op.batch_alter_table("circles") as batch_op:
        batch_op.add_column(
            sa.Column("status", sa.String(16), server_default="draft", nullable=False)
        )
        batch_op.add_column(
            sa.Column("synthetic", sa.Boolean(), server_default=sa.false(), nullable=False)
        )
        batch_op.add_column(sa.Column("max_members", sa.Integer(), nullable=True))
        batch_op.add_column(sa.Column("contribution_kobo", sa.Integer(), nullable=True))
        batch_op.add_column(sa.Column("frequency", sa.String(16), nullable=True))
        batch_op.add_column(sa.Column("due_time_local", sa.Time(), nullable=True))
        batch_op.add_column(sa.Column("current_rules_version", sa.String(128), nullable=True))
        batch_op.add_column(sa.Column("activated_at", sa.DateTime(timezone=True), nullable=True))
        batch_op.create_check_constraint(
            "status", "status IN ('draft', 'inviting', 'active', 'completed')"
        )
        batch_op.create_check_constraint("frequency", "frequency IS NULL OR frequency = 'weekly'")
        batch_op.create_check_constraint("max_members", "max_members IS NULL OR max_members > 0")
        batch_op.create_check_constraint(
            "contribution_kobo",
            "contribution_kobo IS NULL OR contribution_kobo > 0",
        )

    op.create_table(
        "circle_invitations",
        sa.Column("id", sa.String(36), nullable=False),
        sa.Column("circle_id", sa.String(36), nullable=False),
        sa.Column("token_hash", sa.String(64), nullable=False),
        sa.Column("created_by_user_id", sa.String(36), nullable=False),
        sa.Column("max_uses", sa.Integer(), nullable=False),
        sa.Column("uses", sa.Integer(), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint("max_uses > 0", name=op.f("ck_circle_invitations_max_uses")),
        sa.CheckConstraint(
            "uses >= 0 AND uses <= max_uses", name=op.f("ck_circle_invitations_uses")
        ),
        sa.ForeignKeyConstraint(
            ["circle_id"],
            ["circles.id"],
            name=op.f("fk_circle_invitations_circle_id_circles"),
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["created_by_user_id"],
            ["users.id"],
            name=op.f("fk_circle_invitations_created_by_user_id_users"),
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_circle_invitations")),
        sa.UniqueConstraint("token_hash", name=op.f("uq_circle_invitations_token_hash")),
    )
    op.create_index("ix_circle_invitations_circle_id", "circle_invitations", ["circle_id"])

    op.create_table(
        "circle_periods",
        sa.Column("id", sa.String(36), nullable=False),
        sa.Column("circle_id", sa.String(36), nullable=False),
        sa.Column("period_number", sa.Integer(), nullable=False),
        sa.Column("due_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("grace_deadline_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("status", sa.String(16), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint("period_number > 0", name=op.f("ck_circle_periods_period_number")),
        sa.CheckConstraint(
            "status IN ('open', 'completed')", name=op.f("ck_circle_periods_status")
        ),
        sa.ForeignKeyConstraint(
            ["circle_id"],
            ["circles.id"],
            name=op.f("fk_circle_periods_circle_id_circles"),
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_circle_periods")),
        sa.UniqueConstraint("circle_id", "period_number", name="uq_circle_period_number"),
    )

    op.create_table(
        "circle_obligations",
        sa.Column("id", sa.String(36), nullable=False),
        sa.Column("period_id", sa.String(36), nullable=False),
        sa.Column("membership_id", sa.String(36), nullable=False),
        sa.Column("amount_kobo", sa.Integer(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint("amount_kobo > 0", name=op.f("ck_circle_obligations_amount_kobo")),
        sa.ForeignKeyConstraint(
            ["period_id"],
            ["circle_periods.id"],
            name=op.f("fk_circle_obligations_period_id_circle_periods"),
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["membership_id"],
            ["memberships.id"],
            name=op.f("fk_circle_obligations_membership_id_memberships"),
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_circle_obligations")),
        sa.UniqueConstraint("period_id", "membership_id", name="uq_obligation_period_membership"),
    )
    op.create_index("ix_circle_obligations_membership_id", "circle_obligations", ["membership_id"])

    op.create_table(
        "simulated_contributions",
        sa.Column("id", sa.String(36), nullable=False),
        sa.Column("circle_id", sa.String(36), nullable=False),
        sa.Column("obligation_id", sa.String(36), nullable=False),
        sa.Column("actor_user_id", sa.String(36), nullable=False),
        sa.Column("amount_kobo", sa.Integer(), nullable=False),
        sa.Column("idempotency_key", sa.String(128), nullable=False),
        sa.Column("mode", sa.String(16), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint("amount_kobo > 0", name=op.f("ck_simulated_contributions_amount_kobo")),
        sa.CheckConstraint("mode = 'simulated'", name=op.f("ck_simulated_contributions_mode")),
        sa.ForeignKeyConstraint(
            ["circle_id"],
            ["circles.id"],
            name=op.f("fk_simulated_contributions_circle_id_circles"),
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["obligation_id"],
            ["circle_obligations.id"],
            name=op.f("fk_simulated_contributions_obligation_id_circle_obligations"),
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["actor_user_id"],
            ["users.id"],
            name=op.f("fk_simulated_contributions_actor_user_id_users"),
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_simulated_contributions")),
        sa.UniqueConstraint(
            "circle_id", "actor_user_id", "idempotency_key", name="uq_sim_contribution_idempotency"
        ),
    )
    op.create_index(
        "ix_simulated_contributions_obligation_id", "simulated_contributions", ["obligation_id"]
    )

    op.create_table(
        "circle_payouts",
        sa.Column("id", sa.String(36), nullable=False),
        sa.Column("period_id", sa.String(36), nullable=False),
        sa.Column("recipient_membership_id", sa.String(36), nullable=False),
        sa.Column("amount_kobo", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(24), nullable=False),
        sa.Column("approved_by_user_id", sa.String(36), nullable=True),
        sa.Column("approved_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("settled_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint("amount_kobo > 0", name=op.f("ck_circle_payouts_amount_kobo")),
        sa.CheckConstraint(
            "status IN ('scheduled', 'held', 'awaiting_approval', 'processing', 'settled')",
            name=op.f("ck_circle_payouts_status"),
        ),
        sa.ForeignKeyConstraint(
            ["period_id"],
            ["circle_periods.id"],
            name=op.f("fk_circle_payouts_period_id_circle_periods"),
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["recipient_membership_id"],
            ["memberships.id"],
            name=op.f("fk_circle_payouts_recipient_membership_id_memberships"),
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["approved_by_user_id"],
            ["users.id"],
            name=op.f("fk_circle_payouts_approved_by_user_id_users"),
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_circle_payouts")),
        sa.UniqueConstraint("period_id", name="uq_circle_payout_period"),
    )

    op.create_table(
        "circle_payout_events",
        sa.Column("id", sa.String(36), nullable=False),
        sa.Column("payout_id", sa.String(36), nullable=False),
        sa.Column("actor_user_id", sa.String(36), nullable=False),
        sa.Column("action", sa.String(24), nullable=False),
        sa.Column("reference", sa.String(128), nullable=True),
        sa.Column("request_id", sa.String(36), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "action IN ('approved', 'simulated_settled')",
            name=op.f("ck_circle_payout_events_action"),
        ),
        sa.ForeignKeyConstraint(
            ["payout_id"],
            ["circle_payouts.id"],
            name=op.f("fk_circle_payout_events_payout_id_circle_payouts"),
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["actor_user_id"],
            ["users.id"],
            name=op.f("fk_circle_payout_events_actor_user_id_users"),
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_circle_payout_events")),
        sa.UniqueConstraint("payout_id", "action", name="uq_circle_payout_event_action"),
    )
    op.create_index("ix_circle_payout_events_payout_id", "circle_payout_events", ["payout_id"])

    if op.get_bind().dialect.name == "postgresql":
        op.execute(
            "CREATE FUNCTION reject_simulated_event_mutation() RETURNS trigger "
            "LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION "
            "'simulated financial events are append-only'; "
            "END; $$"
        )
        for table_name, trigger_name in (
            ("simulated_contributions", "tr_simulated_contributions_append_only"),
            ("circle_payout_events", "tr_circle_payout_events_append_only"),
        ):
            op.execute(
                f"CREATE TRIGGER {trigger_name} BEFORE UPDATE OR DELETE ON {table_name} "
                "FOR EACH ROW EXECUTE FUNCTION reject_simulated_event_mutation()"
            )
    elif op.get_bind().dialect.name == "sqlite":
        for table_name, stem in (
            ("simulated_contributions", "simulated_contributions"),
            ("circle_payout_events", "circle_payout_events"),
        ):
            for operation in ("UPDATE", "DELETE"):
                op.execute(
                    f"CREATE TRIGGER tr_{stem}_no_{operation.lower()} "
                    f"BEFORE {operation} ON {table_name} "
                    "BEGIN SELECT RAISE(ABORT, 'simulated financial events are append-only'); END"
                )


def downgrade() -> None:
    dialect_name = op.get_bind().dialect.name
    if dialect_name == "postgresql":
        op.execute("DROP TRIGGER tr_circle_payout_events_append_only ON circle_payout_events")
        op.execute("DROP TRIGGER tr_simulated_contributions_append_only ON simulated_contributions")
        op.execute("DROP FUNCTION reject_simulated_event_mutation()")
    elif dialect_name == "sqlite":
        for stem in ("circle_payout_events", "simulated_contributions"):
            op.execute(f"DROP TRIGGER tr_{stem}_no_delete")
            op.execute(f"DROP TRIGGER tr_{stem}_no_update")
    op.drop_index("ix_circle_payout_events_payout_id", table_name="circle_payout_events")
    op.drop_table("circle_payout_events")
    op.drop_table("circle_payouts")
    op.drop_index("ix_simulated_contributions_obligation_id", table_name="simulated_contributions")
    op.drop_table("simulated_contributions")
    op.drop_index("ix_circle_obligations_membership_id", table_name="circle_obligations")
    op.drop_table("circle_obligations")
    op.drop_table("circle_periods")
    op.drop_index("ix_circle_invitations_circle_id", table_name="circle_invitations")
    op.drop_table("circle_invitations")
    with op.batch_alter_table("circles") as batch_op:
        batch_op.drop_constraint("contribution_kobo", type_="check")
        batch_op.drop_constraint("max_members", type_="check")
        batch_op.drop_constraint("frequency", type_="check")
        batch_op.drop_constraint("status", type_="check")
        for column in (
            "activated_at",
            "current_rules_version",
            "due_time_local",
            "frequency",
            "contribution_kobo",
            "max_members",
            "synthetic",
            "status",
        ):
            batch_op.drop_column(column)
