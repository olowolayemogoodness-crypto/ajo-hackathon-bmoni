from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.api.session import get_current_identity
from app.auth.authorization import require_active_membership
from app.auth.identity import VerifiedIdentity
from app.db.session import get_db_session
from app.modules.circles.repository import get_circle_for_active_member
from app.modules.users.repository import resolve_user

router = APIRouter(prefix="/v1/circles", tags=["circles"])


class CircleResponse(BaseModel):
    id: str
    name: str


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
