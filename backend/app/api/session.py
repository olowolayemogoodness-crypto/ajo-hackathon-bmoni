from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.auth.identity import (
    IdentityProviderUnavailable,
    IdentityVerifier,
    InvalidFirebaseToken,
    VerifiedIdentity,
)
from app.db.session import get_db_session
from app.modules.users.repository import resolve_user

router = APIRouter(prefix="/v1", tags=["session"])
bearer = HTTPBearer(auto_error=False)


class SessionUser(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str
    display_name: str | None = Field(default=None, alias="displayName")


class SessionResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    user: SessionUser
    memberships: list[dict[str, object]]
    request_id: str = Field(alias="requestId")


def get_current_identity(
    request: Request,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
) -> VerifiedIdentity:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED)

    verifier: IdentityVerifier = request.app.state.identity_verifier
    try:
        return verifier.verify(credentials.credentials)
    except InvalidFirebaseToken as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED) from exc
    except IdentityProviderUnavailable as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE) from exc


@router.post("/session", response_model=SessionResponse)
def create_session(
    request: Request,
    identity: Annotated[VerifiedIdentity, Depends(get_current_identity)],
    session: Annotated[Session, Depends(get_db_session)],
) -> SessionResponse:
    try:
        user = resolve_user(session, identity)
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE) from exc

    return SessionResponse(
        user=SessionUser(id=user.id, display_name=user.display_name),
        memberships=[],
        request_id=request.state.request_id,
    )
