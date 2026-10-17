from datetime import date
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Request, status
from pydantic import BaseModel, ConfigDict, Field, field_validator
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.api.session import get_current_identity
from app.auth.authorization import require_active_membership
from app.auth.identity import VerifiedIdentity
from app.db.session import get_db_session
from app.modules.circles.demo_service import (
    activate_demo_circle,
    approve_demo_payout,
    create_demo_circle,
    get_demo_setup,
    get_demo_summary,
    record_simulated_contribution,
    settle_demo_payout,
)
from app.modules.circles.membership_service import (
    MembershipActionResult,
    leave_circle,
    promote_organizer,
    revoke_membership,
)
from app.modules.circles.repository import get_circle_for_active_member, list_active_memberships
from app.modules.users.repository import resolve_user

router = APIRouter(prefix="/v1/circles", tags=["circles"])


class CircleResponse(BaseModel):
    id: str
    name: str


class CircleListResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    circles: list[CircleResponse]
    request_id: str = Field(alias="requestId")


class MembershipReasonRequest(BaseModel):
    reason: str = Field(min_length=1, max_length=500)

    @field_validator("reason")
    @classmethod
    def require_non_whitespace_reason(cls, value: str) -> str:
        reason = value.strip()
        if not reason:
            raise ValueError("reason must not be blank")
        return reason


class MembershipLeaveRequest(BaseModel):
    reason: str | None = Field(default=None, max_length=500)

    @field_validator("reason")
    @classmethod
    def normalize_reason(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return value.strip() or None


class MembershipActionResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    membership_id: str = Field(alias="membershipId")
    circle_id: str = Field(alias="circleId")
    status: str
    role: str
    event_id: str = Field(alias="eventId")
    request_id: str = Field(alias="requestId")


class DemoCircleCreateRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    name: str = Field(min_length=1, max_length=160)
    max_members: int = Field(alias="maxMembers", ge=2, le=12)
    contribution_kobo: int = Field(alias="contributionKobo", gt=0, le=100_000_000)
    accepted_rules_version: str = Field(
        alias="acceptedRulesVersion",
        min_length=1,
        max_length=128,
    )


class DemoCircleActivateRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    payout_recipient_membership_id: str = Field(alias="payoutRecipientMembershipId")
    first_due_date: date = Field(alias="firstDueDate")


class SimulatedContributionRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    amount_kobo: int = Field(alias="amountKobo", gt=0)


def _membership_action_response(result: MembershipActionResult) -> MembershipActionResponse:
    return MembershipActionResponse(
        membership_id=result.membership_id,
        circle_id=result.circle_id,
        status=result.status,
        role=result.role,
        event_id=result.event_id,
        request_id=result.request_id,
    )


@router.post("", status_code=status.HTTP_201_CREATED)
def create_demo_circle_route(
    body: DemoCircleCreateRequest,
    request: Request,
    identity: Annotated[VerifiedIdentity, Depends(get_current_identity)],
    session: Annotated[Session, Depends(get_db_session)],
) -> dict[str, object]:
    try:
        return create_demo_circle(
            session,
            identity,
            request.state.request_id,
            name=body.name,
            max_members=body.max_members,
            contribution_kobo=body.contribution_kobo,
            accepted_rules_version=body.accepted_rules_version,
            settings=request.app.state.settings,
        )
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE) from exc


@router.get("", response_model=CircleListResponse)
def list_circles(
    request: Request,
    identity: Annotated[VerifiedIdentity, Depends(get_current_identity)],
    session: Annotated[Session, Depends(get_db_session)],
    membership: Literal["active"] = Query(...),
) -> CircleListResponse:
    try:
        user = resolve_user(session, identity)
        memberships = list_active_memberships(session, user.id)
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE) from exc

    return CircleListResponse(
        circles=[
            CircleResponse(id=circle.id, name=circle.name)
            for _membership, circle in memberships
        ],
        requestId=request.state.request_id,
    )


@router.get("/{circle_id}/demo-setup")
def get_demo_setup_route(
    circle_id: str,
    request: Request,
    identity: Annotated[VerifiedIdentity, Depends(get_current_identity)],
    session: Annotated[Session, Depends(get_db_session)],
) -> dict[str, object]:
    try:
        return get_demo_setup(session, identity, circle_id, request.app.state.settings)
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE) from exc


@router.post("/{circle_id}/activate")
def activate_demo_circle_route(
    circle_id: str,
    body: DemoCircleActivateRequest,
    request: Request,
    identity: Annotated[VerifiedIdentity, Depends(get_current_identity)],
    session: Annotated[Session, Depends(get_db_session)],
) -> dict[str, object]:
    try:
        return activate_demo_circle(
            session,
            identity,
            circle_id,
            request.state.request_id,
            payout_recipient_membership_id=body.payout_recipient_membership_id,
            first_due_date=body.first_due_date,
            settings=request.app.state.settings,
        )
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE) from exc


@router.get("/{circle_id}/demo-summary")
def get_demo_summary_route(
    circle_id: str,
    request: Request,
    identity: Annotated[VerifiedIdentity, Depends(get_current_identity)],
    session: Annotated[Session, Depends(get_db_session)],
) -> dict[str, object]:
    try:
        return get_demo_summary(session, identity, circle_id, request.app.state.settings)
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE) from exc


@router.post("/{circle_id}/demo/contributions/{membership_id}")
def record_demo_contribution_route(
    circle_id: str,
    membership_id: str,
    body: SimulatedContributionRequest,
    request: Request,
    identity: Annotated[VerifiedIdentity, Depends(get_current_identity)],
    session: Annotated[Session, Depends(get_db_session)],
    idempotency_key: str = Header(
        ...,
        alias="Idempotency-Key",
        min_length=1,
        max_length=128,
    ),
) -> dict[str, object]:
    try:
        return record_simulated_contribution(
            session,
            identity,
            circle_id,
            membership_id,
            request.state.request_id,
            amount_kobo=body.amount_kobo,
            idempotency_key=idempotency_key,
            settings=request.app.state.settings,
        )
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE) from exc


@router.post("/{circle_id}/payout/approve")
def approve_demo_payout_route(
    circle_id: str,
    request: Request,
    identity: Annotated[VerifiedIdentity, Depends(get_current_identity)],
    session: Annotated[Session, Depends(get_db_session)],
) -> dict[str, object]:
    try:
        return approve_demo_payout(
            session,
            identity,
            circle_id,
            request.state.request_id,
            request.app.state.settings,
        )
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE) from exc


@router.post("/{circle_id}/demo/payout/settle")
def settle_demo_payout_route(
    circle_id: str,
    request: Request,
    identity: Annotated[VerifiedIdentity, Depends(get_current_identity)],
    session: Annotated[Session, Depends(get_db_session)],
) -> dict[str, object]:
    try:
        return settle_demo_payout(
            session,
            identity,
            circle_id,
            request.state.request_id,
            request.app.state.settings,
        )
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE) from exc


@router.get("/{circle_id}", response_model=CircleResponse)
def get_circle(
    circle_id: str,
    identity: Annotated[VerifiedIdentity, Depends(get_current_identity)],
    session: Annotated[Session, Depends(get_db_session)],
) -> CircleResponse:
    try:
        user = resolve_user(session, identity)
        require_active_membership(session, user.id, circle_id)
        circle = get_circle_for_active_member(session, user.id, circle_id)
        if circle is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
        return CircleResponse(id=circle.id, name=circle.name)
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE) from exc


@router.post(
    "/{circle_id}/memberships/{membership_id}/revoke",
    response_model=MembershipActionResponse,
)
def revoke_circle_membership(
    circle_id: str,
    membership_id: str,
    body: MembershipReasonRequest,
    request: Request,
    identity: Annotated[VerifiedIdentity, Depends(get_current_identity)],
    session: Annotated[Session, Depends(get_db_session)],
) -> MembershipActionResponse:
    try:
        result = revoke_membership(
            session,
            identity,
            circle_id,
            membership_id,
            request.state.request_id,
            body.reason,
        )
        return _membership_action_response(result)
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE) from exc


@router.post(
    "/{circle_id}/memberships/me/leave",
    response_model=MembershipActionResponse,
)
def leave_circle_membership(
    circle_id: str,
    request: Request,
    identity: Annotated[VerifiedIdentity, Depends(get_current_identity)],
    session: Annotated[Session, Depends(get_db_session)],
    body: MembershipLeaveRequest | None = None,
) -> MembershipActionResponse:
    try:
        result = leave_circle(
            session,
            identity,
            circle_id,
            request.state.request_id,
            body.reason if body is not None else None,
        )
        return _membership_action_response(result)
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE) from exc


@router.post(
    "/{circle_id}/memberships/{membership_id}/promote-organizer",
    response_model=MembershipActionResponse,
)
def promote_circle_organizer(
    circle_id: str,
    membership_id: str,
    request: Request,
    identity: Annotated[VerifiedIdentity, Depends(get_current_identity)],
    session: Annotated[Session, Depends(get_db_session)],
) -> MembershipActionResponse:
    try:
        result = promote_organizer(
            session,
            identity,
            circle_id,
            membership_id,
            request.state.request_id,
        )
        return _membership_action_response(result)
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE) from exc
