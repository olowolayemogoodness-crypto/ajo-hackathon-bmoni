from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.api.session import get_current_identity
from app.auth.identity import VerifiedIdentity
from app.db.session import get_db_session
from app.modules.circles.demo_service import accept_demo_invitation, inspect_demo_invitation

router = APIRouter(prefix="/v1/invitations", tags=["invitations"])


class InvitationCodeRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    invitation_code: str = Field(alias="invitationCode", min_length=8, max_length=80)


class AcceptInvitationRequest(InvitationCodeRequest):
    accepted_rules_version: str = Field(alias="acceptedRulesVersion", min_length=1, max_length=128)


@router.post("/inspect")
def inspect_invitation_route(
    body: InvitationCodeRequest,
    request: Request,
    _: Annotated[VerifiedIdentity, Depends(get_current_identity)],
    session: Annotated[Session, Depends(get_db_session)],
) -> dict[str, object]:
    try:
        return inspect_demo_invitation(
            session,
            body.invitation_code,
            request.app.state.settings,
        )
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE) from exc


@router.post("/accept", status_code=status.HTTP_201_CREATED)
def accept_invitation_route(
    body: AcceptInvitationRequest,
    request: Request,
    identity: Annotated[VerifiedIdentity, Depends(get_current_identity)],
    session: Annotated[Session, Depends(get_db_session)],
) -> dict[str, object]:
    try:
        return accept_demo_invitation(
            session,
            identity,
            request.state.request_id,
            code=body.invitation_code,
            accepted_rules_version=body.accepted_rules_version,
            settings=request.app.state.settings,
        )
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE) from exc