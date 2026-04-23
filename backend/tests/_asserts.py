"""Test assertion helpers for the structured validation-error response shape.

Routes that have been migrated to ``raise_validation(Code.X.Y)`` return
responses of the form ``{detail: [{code, field, params?}, ...]}``. Use
``assert_error_code`` in tests instead of matching on free-text strings.
"""

from typing import Any


def assert_error_code(
    response: Any, expected_code: str, expected_field: str | None = ...
) -> dict:
    """Assert a response carries the given validation code. Returns the match.

    ``expected_field``:
      - Default (``...``): field is not checked — any match on code works.
      - ``None``: match only entries with ``field=None`` (model-level errors).
      - str: match only entries with that exact field name.
    """
    data = response.json()
    detail = data.get("detail")
    assert isinstance(detail, list), (
        f"expected structured detail list, got {type(detail).__name__}: {detail!r}"
    )
    for entry in detail:
        if entry.get("code") != expected_code:
            continue
        if expected_field is not ... and entry.get("field") != expected_field:
            continue
        return entry
    raise AssertionError(
        f"no error with code={expected_code!r}"
        + (f" field={expected_field!r}" if expected_field is not ... else "")
        + f" in {detail!r}"
    )
