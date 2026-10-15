from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.auth.identity import VerifiedIdentity
from app.modules.users.models import User


def resolve_user(session: Session, identity: VerifiedIdentity) -> User:
    user = session.scalar(select(User).where(User.firebase_uid == identity.firebase_uid))
    if user is not None:
        return user

    user = User(firebase_uid=identity.firebase_uid, display_name=identity.display_name)
    session.add(user)
    try:
        session.commit()
    except IntegrityError:
        session.rollback()
        user = session.scalar(select(User).where(User.firebase_uid == identity.firebase_uid))
        if user is None:
            raise
    return user
