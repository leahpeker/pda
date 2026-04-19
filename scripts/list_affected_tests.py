#!/usr/bin/env python3
"""Emit pytest paths (relative to backend/, e.g. tests/test_foo.py) for tests likely affected by git changes.

Compares the working tree (including staged + unstaged) to merge-base(HEAD, BASE_REF).
Print one path per line. Special lines:
  __FULL__  — run the full suite (conservative: infra / migrations / unknown paths).
  (empty)   — no backend-relevant paths changed; caller may skip pytest.

Override base with env TEST_BASE or argv: --base REF
"""

from __future__ import annotations

import argparse
import os
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

# When any of these paths (prefix match on normalized diff paths) change, run everything.
FULL_PREFIXES: tuple[str, ...] = (
    "backend/tests/conftest.py",
    "pyproject.toml",
    "Makefile",
    "backend/config/settings.py",
    "backend/config/asgi.py",
    "backend/config/wsgi.py",
    "backend/config/urls.py",
)

# Any migration edit can change DB state assumptions — run full suite.
MIGRATION_MARK = "/migrations/"

# Paths relative to backend/ for `pytest` when cwd is backend/.
USERS_TESTS: frozenset[str] = frozenset(
    {
        "tests/test_user_model.py",
        "tests/test_users.py",
        "tests/test_auth.py",
        "tests/test_auth_cookie.py",
        "tests/test_auth_update_me.py",
        "tests/test_request_login_link.py",
    }
)

NOTIFICATIONS_TESTS: frozenset[str] = frozenset(
    {
        "tests/test_notifications.py",
        "tests/test_in_app_notifications.py",
        "tests/test_sse.py",
    }
)

# Community app: broad bundle (excludes user-, notification-, and pure-config tests).
COMMUNITY_TESTS: frozenset[str] = frozenset(
    {
        "tests/test_api.py",
        "tests/test_calendar.py",
        "tests/test_community.py",
        "tests/test_seed.py",
        "tests/test_join_request_submission.py",
        "tests/test_join_request_management.py",
        "tests/test_event_cancel.py",
        "tests/test_event_capacity.py",
        "tests/test_event_drafts.py",
        "tests/test_event_flags.py",
        "tests/test_event_helpers.py",
        "tests/test_event_link_validation.py",
        "tests/test_event_management.py",
        "tests/test_event_visibility.py",
        "tests/test_rsvp.py",
        "tests/test_polls.py",
        "tests/test_guidelines.py",
        "tests/test_feedback.py",
        "tests/test_docs.py",
        "tests/test_photos.py",
        "tests/test_prosemirror_html.py",
        "tests/test_delta_html.py",
        "tests/test_cohost_notifications.py",
    }
)

CONFIG_TESTS: frozenset[str] = frozenset(
    {
        "tests/test_settings.py",
        "tests/test_cache_headers.py",
        "tests/test_logging.py",
        "tests/test_api.py",
        "tests/test_sse.py",
    }
)

BACKEND_BUNDLES: tuple[tuple[str, frozenset[str]], ...] = (
    ("backend/users/", USERS_TESTS),
    ("backend/notifications/", NOTIFICATIONS_TESTS),
    ("backend/community/", COMMUNITY_TESTS),
    ("backend/config/", CONFIG_TESTS),
)


def _run_git(args: list[str]) -> str:
    proc = subprocess.run(
        ["git", *args],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        return ""
    return proc.stdout.strip()


def _resolve_base(explicit: str | None) -> str | None:
    if explicit:
        if _run_git(["rev-parse", "--verify", explicit]):
            return explicit
        return None
    env_base = os.environ.get("TEST_BASE", "").strip()
    if env_base and _run_git(["rev-parse", "--verify", env_base]):
        return env_base
    for candidate in ("@{upstream}", "origin/main", "origin/master"):
        if _run_git(["rev-parse", "--verify", candidate]):
            return candidate
    return None


def _normalize_path(raw: str) -> str:
    return raw.replace("\\", "/").strip()


def _needs_full(path: str) -> bool:
    if MIGRATION_MARK in path:
        return True
    for prefix in FULL_PREFIXES:
        if path == prefix or path.startswith(prefix + "/"):
            return True
    return False


def _test_path_from_diff(p: str) -> str | None:
    """Map backend/tests/test_foo.py diff path to pytest arg tests/test_foo.py."""
    if not p.startswith("backend/tests/") or not p.endswith(".py"):
        return None
    name = p.rsplit("/", 1)[-1]
    if not name.startswith("test_"):
        return None
    return "tests/" + name


def _bundle_for_backend_source(p: str) -> frozenset[str] | None:
    """Return tests bundle for app code path, or None if unknown under backend/."""
    for prefix, bundle in BACKEND_BUNDLES:
        if p.startswith(prefix):
            return bundle
    return None


def _classify_and_collect(paths: list[str]) -> set[str] | None:
    """Return set of paths relative to backend/, or None if full suite required."""
    candidates: set[str] = set()
    touched_backend = False

    for raw in paths:
        p = _normalize_path(raw)
        if not p:
            continue
        if p.startswith("backend/"):
            touched_backend = True
        if _needs_full(p):
            return None
        if not p.startswith("backend/"):
            continue
        if rel_test := _test_path_from_diff(p):
            candidates.add(rel_test)
            continue

        bundle = _bundle_for_backend_source(p)
        if bundle is None:
            return None
        candidates.update(bundle)

    if not touched_backend:
        # Only non-backend files (e.g. frontend) — nothing to run.
        return set()
    if not candidates:
        # e.g. only non-Python under backend/
        return None

    return candidates


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--base",
        default=None,
        help="git ref for merge-base (default: TEST_BASE env, then @{upstream}, origin/main)",
    )
    args = parser.parse_args()

    base = _resolve_base(args.base)
    if not base:
        print("__FULL__")
        return 0

    merge_base = _run_git(["merge-base", "HEAD", base])
    if not merge_base:
        print("__FULL__")
        return 0

    diff_out = _run_git(["diff", "--name-only", merge_base])
    paths = [ln for ln in diff_out.splitlines() if ln.strip()]

    result = _classify_and_collect(paths)
    if result is None:
        print("__FULL__")
        return 0

    if not result:
        return 0

    for p in sorted(result):
        print(p)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
