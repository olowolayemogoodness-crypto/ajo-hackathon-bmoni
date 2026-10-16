from typing import Annotated

from fastapi import APIRouter, Depends, Request

from app.api.session import get_current_identity
from app.auth.identity import VerifiedIdentity
from app.modules.circles.demo_service import get_demo_rules

router = APIRouter(prefix="/v1/demo", tags=["demo"])


@router.get("/rules")
def read_demo_rules(
    request: Request,
    _: Annotated[VerifiedIdentity, Depends(get_current_identity)],
) -> dict[str, str]:
    return get_demo_rules(request.app.state.settings)