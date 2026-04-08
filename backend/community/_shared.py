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


_DISPLAY_NAME_REJECT_RE = re.compile(r'[\d@#$%^&*()+=\[\]{}<>|\\/:;!?~`"]')


def validate_display_name(name: str) -> str | None:
    """Return an error message if the display name is invalid, or None if valid.

    Allows Unicode letters, combining marks, apostrophes, hyphens, spaces, and periods.
    Rejects digits, email/URL characters, and names that contain no letters.
    """
    stripped = name.strip()
    if not stripped:
        return "display name is required"
    if len(stripped) > 64:
        return "display name must be at most 64 characters"
    if _DISPLAY_NAME_REJECT_RE.search(stripped):
        return "display name contains invalid characters — no numbers or symbols"
    if all(c in " '-." for c in stripped):
        return "display name must contain at least one letter"
    return None


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
