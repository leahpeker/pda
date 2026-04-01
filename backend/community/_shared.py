"""Shared utilities, schemas, and auth used across community API modules."""

import logging
import re

import phonenumbers
from django.contrib.auth.models import AnonymousUser
from django.http import HttpRequest
from ninja.security import HttpBearer
from ninja_jwt.authentication import JWTAuth, JWTBaseAuthentication  # noqa: F401
from pydantic import BaseModel
from users.models import User as UserModel

logger = logging.getLogger("pda.community")


class OptionalJWTAuth(JWTBaseAuthentication, HttpBearer):
    """JWT auth that returns AnonymousUser instead of None/401 when no/invalid token."""

    def authenticate(self, request: HttpRequest, token: str):
        try:
            return self.jwt_authenticate(request, token)
        except Exception:
            return AnonymousUser()

    def __call__(self, request: HttpRequest):
        result = super().__call__(request)
        # No Authorization header → super().__call__ returns None
        if result is None:
            return AnonymousUser()
        return result


_optional_jwt = OptionalJWTAuth()


class ErrorOut(BaseModel):
    detail: str


DISPLAY_NAME_RE = re.compile(r"^[a-zA-Z ]+$")


def _validate_phone(raw: str) -> str:
    try:
        parsed = phonenumbers.parse(raw, None)
    except phonenumbers.phonenumberutil.NumberParseException as e:
        raise ValueError(str(e)) from e
    if not phonenumbers.is_valid_number(parsed):
        raise ValueError(f"Invalid phone number: {raw}")
    return phonenumbers.format_number(parsed, phonenumbers.PhoneNumberFormat.E164)


def _authenticated_user(requesting_user) -> "UserModel | None":
    """Return the user if authenticated, None if anonymous."""
    if requesting_user is None or isinstance(requesting_user, AnonymousUser):
        return None
    return requesting_user


def _members_only(value, default, is_authed: bool):
    """Return value if user is authenticated, default otherwise."""
    return value if is_authed else default
