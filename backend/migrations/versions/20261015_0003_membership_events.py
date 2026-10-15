"""Add append-only membership lifecycle events.

Revision ID: 20261015_0003
Revises: 20261015_0002
Create Date: 2026-10-15
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20261015_0003"
down_revision: str | None = "20261015_0002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "membership_events",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("circle_id", sa.String(length=36), nullable=False),
        sa.Column("membership_id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("actor_user_id", sa.String(length=36), nullable=False),
        sa.Column("action", sa.String(length=32), nullable=False),
        sa.Column("previous_status", sa.String(length=16), nullable=True),
        sa.Column("resulting_status", sa.String(length=16), nullable=True),
        sa.Column("previous_role", sa.String(length=16), nullable=True),
        sa.Column("resulting_role", sa.String(length=16), nullable=True),
        sa.Column("invitation_id", sa.String(length=36), nullable=True),
        sa.Column("accepted_rules_version", sa.String(length=128), nullable=True),
        sa.Column("reason", sa.String(length=500), nullable=True),
        sa.Column("request_id", sa.String(length=36), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "action IN ('membership_created', 'membership_rejoined', 'member_left', "
            "'member_revoked', 'organizer_promoted')",
            name=op.f("ck_membership_events_action"),
        ),
        sa.CheckConstraint(
            "previous_status IS NULL OR previous_status IN ('active', 'inactive', 'revoked')",
            name=op.f("ck_membership_events_previous_status"),
        ),
        sa.CheckConstraint(
            "resulting_status IS NULL OR resulting_status IN ('active', 'inactive', 'revoked')",
            name=op.f("ck_membership_events_resulting_status"),
        ),
        sa.CheckConstraint(
            "previous_role IS NULL OR previous_role IN ('organizer', 'member')",
            name=op.f("ck_membership_events_previous_role"),
        ),
        sa.CheckConstraint(
            "resulting_role IS NULL OR resulting_role IN ('organizer', 'member')",
            name=op.f("ck_membership_events_resulting_role"),
        ),
        sa.ForeignKeyConstraint(
            ["circle_id"],
            ["circles.id"],
            name=op.f("fk_membership_events_circle_id_circles"),
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["membership_id"],
            ["memberships.id"],
            name=op.f("fk_membership_events_membership_id_memberships"),
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name=op.f("fk_membership_events_user_id_users"),
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["actor_user_id"],
            ["users.id"],
            name=op.f("fk_membership_events_actor_user_id_users"),
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_membership_events")),
    )
    op.create_index(
        "ix_membership_events_circle_created_at",
        "membership_events",
        ["circle_id", "created_at"],
    )
    op.create_index(
        "ix_membership_events_membership_id",
        "membership_events",
        ["membership_id"],
    )

    if op.get_bind().dialect.name == "postgresql":
        op.execute(
            "CREATE FUNCTION reject_membership_event_mutation() RETURNS trigger "
            "LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'membership events are append-only'; "
            "END; $$"
        )
        op.execute(
            "CREATE TRIGGER tr_membership_events_append_only "
            "BEFORE UPDATE OR DELETE ON membership_events "
            "FOR EACH ROW EXECUTE FUNCTION reject_membership_event_mutation()"
        )
    elif op.get_bind().dialect.name == "sqlite":
        op.execute(
            "CREATE TRIGGER tr_membership_events_no_update BEFORE UPDATE ON membership_events "
            "BEGIN SELECT RAISE(ABORT, 'membership events are append-only'); END"
        )
        op.execute(
            "CREATE TRIGGER tr_membership_events_no_delete BEFORE DELETE ON membership_events "
            "BEGIN SELECT RAISE(ABORT, 'membership events are append-only'); END"
        )


def downgrade() -> None:
    dialect_name = op.get_bind().dialect.name
    if dialect_name == "postgresql":
        op.execute("DROP TRIGGER tr_membership_events_append_only ON membership_events")
        op.execute("DROP FUNCTION reject_membership_event_mutation()")
    elif dialect_name == "sqlite":
        op.execute("DROP TRIGGER tr_membership_events_no_delete")
        op.execute("DROP TRIGGER tr_membership_events_no_update")
    op.drop_index("ix_membership_events_membership_id", table_name="membership_events")
    op.drop_index("ix_membership_events_circle_created_at", table_name="membership_events")
    op.drop_table("membership_events")
