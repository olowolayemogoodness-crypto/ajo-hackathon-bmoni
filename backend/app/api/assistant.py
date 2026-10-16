from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel, ConfigDict, Field, field_validator
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.api.session import get_current_identity
from app.auth.identity import VerifiedIdentity
from app.db.session import get_db_session
from app.modules.circles.demo_service import answer_demo_question

router = APIRouter(prefix="/v1/assistant", tags=["assistant"])


class DemoQuestionRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    circle_id: str = Field(alias="circleId", min_length=1, max_length=36)
    question: str = Field(min_length=1, max_length=500)

    @field_validator("question")
    @classmethod
    def require_nonblank_question(cls, value: str) -> str:
        question = value.strip()
        if not question:
            raise ValueError("question must not be blank")
        return question


@router.post("/queries")
def ask_demo_assistant(
    body: DemoQuestionRequest,
    request: Request,
    identity: Annotated[VerifiedIdentity, Depends(get_current_identity)],
    session: Annotated[Session, Depends(get_db_session)],
) -> dict[str, object]:
    try:
        answer = answer_demo_question(
            session,
            identity,
            body.circle_id,
            body.question,
            request.app.state.settings,
        )
        return {**answer, "requestId": request.state.request_id}
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE) from exc