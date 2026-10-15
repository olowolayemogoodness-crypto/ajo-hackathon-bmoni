from dataclasses import dataclass
from typing import Protocol


class InvalidFirebaseToken(Exception):
    pass


class IdentityProviderUnavailable(Exception):
    pass


@dataclass(frozen=True)
class VerifiedIdentity:
    firebase_uid: str
    display_name: str | None


class IdentityVerifier(Protocol):
    def verify(self, token: str) -> VerifiedIdentity: ...


class FirebaseIdentityVerifier:
    def __init__(self, project_id: str, app_name: str = "ajo-api") -> None:
        self._project_id = project_id
        self._app_name = app_name

    def _get_app(self, firebase_admin):
        try:
            return firebase_admin.get_app(self._app_name)
        except ValueError:
            try:
                return firebase_admin.initialize_app(
                    options={"projectId": self._project_id},
                    name=self._app_name,
                )
            except ValueError:
                try:
                    return firebase_admin.get_app(self._app_name)
                except Exception as exc:
                    raise IdentityProviderUnavailable from exc
            except Exception as exc:
                raise IdentityProviderUnavailable from exc
        except Exception as exc:
            raise IdentityProviderUnavailable from exc

    def verify(self, token: str) -> VerifiedIdentity:
        try:
            import firebase_admin
            from firebase_admin import auth
        except ImportError as exc:
            raise IdentityProviderUnavailable from exc

        app = self._get_app(firebase_admin)
        try:
            claims = auth.verify_id_token(token, app=app, check_revoked=True)
        except ValueError as exc:
            raise InvalidFirebaseToken from exc
        except Exception as exc:
            invalid_error_names = {
                "ExpiredIdTokenError",
                "InvalidIdTokenError",
                "RevokedIdTokenError",
                "UserDisabledError",
                "UserNotFoundError",
            }
            if type(exc).__name__ in invalid_error_names:
                raise InvalidFirebaseToken from exc
            raise IdentityProviderUnavailable from exc

        firebase_uid = claims.get("uid")
        if not isinstance(firebase_uid, str) or not firebase_uid:
            raise InvalidFirebaseToken

        display_name = claims.get("name")
        if not isinstance(display_name, str):
            display_name = None
        return VerifiedIdentity(firebase_uid=firebase_uid, display_name=display_name)
