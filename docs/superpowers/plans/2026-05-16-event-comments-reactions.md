# Event Comments and Emoji Reactions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a comment thread with one level of replies and six-emoji reactions to every event detail screen. Logged-in users who have RSVP'd can post, reply, react, and delete their own comments; hosts and `ManageEvents` admins can delete others' comments. New replies notify the parent comment's author.

**Architecture:** Two new Django models (`EventComment`, `EventCommentReaction`) on the existing `community` app, exposed via a new sub-router (`_event_comments.py`) mirroring the existing `EventPoll` pattern. Frontend renders a new `EventCommentsCard` inside `EventMemberSection` below `RsvpSection`, owning its own TanStack Query state. Reply notifications use a new `NotificationType.COMMENT_REPLY` enum value on the existing notifications stack.

**Tech Stack:** Django 5 + Django Ninja (backend), pytest + ninja_jwt (testing), React 18 + TypeScript + Vite + TanStack Query + Zustand (frontend), Vitest + React Testing Library (frontend testing).

**Source spec:** `docs/superpowers/specs/2026-05-15-event-comments-reactions-design.md` (committed to branch `spec/event-comments-reactions`, draft PR #426).

**Worktree:** All work happens in `/Users/leahpeker/development/pda-worktrees/spec-event-comments-reactions/` on branch `spec/event-comments-reactions`. The branch is already pushed and tracked.

---

## Reference cheat sheet

These are the existing patterns the plan mirrors. Read once before starting.

| Concern | Existing pattern | File / line |
|---|---|---|
| Sub-router structure | `EventPoll` endpoints | `backend/community/_polls.py` |
| Sub-router mounting | `router.add_router("", polls_router)` | `backend/community/api.py:56` |
| Schema file | `_event_poll_schemas.py` | `backend/community/_event_poll_schemas.py` |
| External Out-builder | `_poll_out(poll, requesting_user)` (not `from_model`) | `backend/community/_polls.py:107` |
| Validation codes | `class Code: class Event: ...` namespaces | `backend/community/_validation.py` |
| `raise_validation` | `raise_validation(Code.X.Y, status_code=4xx, field=..., action=...)` | `backend/community/_validation.py:200+` |
| Rate-limit decorator | `@rate_limit(key_func=lambda r: str(r.auth.pk), rate="10/m")` directly under `@router.*` | `backend/config/ratelimit.py:29` |
| Visibility gate | `_enforce_event_read_visibility(event, auth_user)` (importable from `_events.py`) | `backend/community/_events.py:218` |
| Edit/manage gate | `_can_edit_event(user, event)` — creator, co-host, `MANAGE_EVENTS` | `backend/community/_events.py:47` |
| EventOut builder | `_event_out(event, requesting_user)` | `backend/community/_event_helpers.py:289` |
| Optional auth | `auth=_optional_jwt` from `community._shared` | `backend/community/_polls.py:178` |
| Required auth | `auth=JWTAuth()` from `ninja_jwt.authentication` | `backend/community/_polls.py:130` |
| Test client | `api_client` (Django `Client`) + `**auth_headers` | `backend/tests/conftest.py` |
| Future dates | `future_iso(days=N)` | `backend/tests/conftest.py` |
| Notification creation | `Notification.objects.create(recipient=..., notification_type=..., event=..., related_user=..., message=...)` + `_notify_users([str(id)])` | `backend/notifications/service.py:235` |
| Frontend TanStack hook | `useEventPoll` + key factory + mapper | `frontend/src/api/eventPolls.ts` |
| Frontend wire mapper | `mapEventPoll(wire)` | `frontend/src/api/eventPollMapper.ts` |
| Auth check | `useAuthStore((s) => s.status === 'authed')` | `frontend/src/auth/store.ts:19` |
| Permission check | `hasPermission(user, Permission.ManageEvents)` | `frontend/src/models/permissions.ts` |
| Card section style | local `Card({label, children})` | `frontend/src/screens/events/EventMemberSection.tsx:98-105` |
| Test wrapper | per-file `<QueryClientProvider>` + `<MemoryRouter>` | `frontend/src/screens/events/EventMemberSection.test.tsx:97` |
| UI primitives | `Button`, `Textarea`, `Dialog`, `ConfirmDialog` | `frontend/src/components/ui/` |

### Conventions to follow

- **UUID PKs:** `id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)`.
- **Timestamps:** `created_at = auto_now_add=True`, `updated_at = auto_now=True` only on mutable rows.
- **Soft-delete:** nullable `deleted_at = models.DateTimeField(null=True, blank=True)`.
- **Rate limit:** every authed write uses `@rate_limit(key_func=lambda r: str(r.auth.pk), rate="10/m")` directly under the `@router.*` decorator.
- **All frontend text is lowercase.** Dynamic strings (date-fns output) get `.toLowerCase()`.
- **No `from_model` static methods.** Use external `_xxx_out(model, requesting_user)` helpers in the router module.
- **Validation codes are wire-format strings — never rename once shipped.** Add new codes under `Code.Comment` in `_validation.py`.
- **No Co-Authored-By** on commits (project rule). Project rule also forbids merging without explicit approval — this plan ends at "ready to merge," not "merged."
- **Pre-merge gate:** `make agent-ci` must pass.

### Things the spec said that the code actually shows differently

- The spec said "all new comment code in `backend/community/models/comment.py`". That is correct for new files. The spec also implied tests would live at `backend/tests/community/test_event_comments.py`; the actual test directory is **flat** at `backend/tests/`. The plan uses `backend/tests/test_event_comments.py`.
- The spec said schemas use a `from_model` static method. The codebase actually uses **external builder functions** (`_poll_out`, `_event_out`). The plan follows the codebase, not the spec wording.
- `_enforce_event_read_visibility` is defined inside `backend/community/_events.py` (line 218), not in `_event_helpers.py`. It is importable from `_events.py`; this is the source of truth for visibility cascade.

---

## PR sequencing

This plan covers two PRs:

- **PR 1 (Tasks 1–18):** Comments + reactions, no notifications. Models, migration, API, schemas, frontend card + composer + reactions + delete, tests. Branch: `spec/event-comments-reactions`. The existing draft PR #426 (currently containing only the design spec) is the target — the implementation commits land on top of the spec commit and the PR is moved out of draft after manual QA.
- **PR 2 (Tasks 19–26):** Reply notifications. `NotificationType.COMMENT_REPLY` enum + migration, `notify_comment_reply` helper, wiring into the reply endpoint, frontend rendering of the new notification type, tests. Branch off PR 1's branch after PR 1 merges, or off main if PR 1 has already merged. New PR.

**Phase 2 (`@mentions`) is explicitly out of scope for this plan.** A separate spec + plan will be written after Phase 1 ships.

---

# PR 1 — Comments and reactions (no notifications)

## Task 1: Bootstrap — verify environment and create code namespace

**Files:**
- Modify: `backend/community/_validation.py` — add `Code.Comment` namespace
- Test: `backend/tests/test_validation_codes.py` (only if existing tests assert the full enum)

Goal: confirm the worktree builds and the dev environment runs, then add the `Code.Comment` namespace so every later task has a stable error-code namespace to reference.

- [ ] **Step 1: Confirm worktree and environment**

Run:
```bash
cd /Users/leahpeker/development/pda-worktrees/spec-event-comments-reactions
git status
git log --oneline -3
make agent-ci
```

Expected:
- `git status` shows clean working tree on `spec/event-comments-reactions`.
- Most recent commit is the spec doc.
- `make agent-ci` passes (this is the pre-existing green baseline).

If `make agent-ci` fails, do not proceed. Fix the underlying issue first.

- [ ] **Step 2: Add `Code.Comment` namespace**

Edit `backend/community/_validation.py`. After the `class Poll:` block (currently ends around line 66, immediately followed by `class Url:`), insert a new `class Comment:` block:

```python
    class Comment:
        NOT_FOUND = "comment.not_found"
        REPLY_DEPTH_EXCEEDED = "comment.reply_depth_exceeded"
        INVALID_EMOJI = "comment.invalid_emoji"
        RSVP_REQUIRED = "comment.rsvp_required"
        PERM_DENIED = "comment.perm_denied"
        EVENT_MISMATCH = "comment.event_mismatch"
```

These six codes cover every error path the API will raise in PR 1.

- [ ] **Step 3: Run validation tests if they exist**

Run:
```bash
cd backend && uv run pytest tests/test_validation_codes.py -q 2>&1 | head -20 || true
```

If the test file exists and tests enumerate all codes, update the expected list. If the file does not exist, this step is a no-op.

- [ ] **Step 4: Run full backend lint + typecheck**

Run:
```bash
make agent-lint
make agent-typecheck
```

Expected: both pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/leahpeker/development/pda-worktrees/spec-event-comments-reactions
git add backend/community/_validation.py
git commit -m "$(cat <<'EOF'
feat(comments): add Code.Comment validation-error namespace

Reserves the comment.* code namespace so later commits can raise
validation errors without bikeshedding the names.
EOF
)"
```

---

## Task 2: Model — `EventComment` and `EventCommentReaction`

**Files:**
- Create: `backend/community/models/comment.py`
- Modify: `backend/community/models/__init__.py:33,76-78` (import + `__all__`)

- [ ] **Step 1: Write the failing test — model fields exist with correct constraints**

Create `backend/tests/test_event_comment_model.py`:

```python
"""Unit tests for the EventComment and EventCommentReaction models."""

import pytest
from django.core.exceptions import ValidationError
from django.db import IntegrityError, transaction

from community.models import (
    Event,
    EventComment,
    EventCommentReaction,
    ReactionEmoji,
)


@pytest.mark.django_db
class TestEventCommentModel:
    def test_create_top_level_comment(self, test_user):
        event = Event.objects.create(
            title="Test Event",
            start_datetime="2030-01-01T00:00:00Z",
            created_by=test_user,
        )
        comment = EventComment.objects.create(
            event=event,
            author=test_user,
            body="hello world",
        )
        assert comment.id is not None
        assert comment.parent is None
        assert comment.deleted_at is None
        assert comment.body == "hello world"

    def test_reply_to_top_level_comment(self, test_user):
        event = Event.objects.create(
            title="Test Event",
            start_datetime="2030-01-01T00:00:00Z",
            created_by=test_user,
        )
        parent = EventComment.objects.create(event=event, author=test_user, body="parent")
        reply = EventComment.objects.create(
            event=event, author=test_user, body="reply", parent=parent
        )
        reply.full_clean()
        assert reply.parent_id == parent.id

    def test_reply_to_reply_fails_clean(self, test_user):
        event = Event.objects.create(
            title="Test Event",
            start_datetime="2030-01-01T00:00:00Z",
            created_by=test_user,
        )
        parent = EventComment.objects.create(event=event, author=test_user, body="parent")
        reply = EventComment.objects.create(
            event=event, author=test_user, body="reply", parent=parent
        )
        nested = EventComment(event=event, author=test_user, body="nested", parent=reply)
        with pytest.raises(ValidationError):
            nested.full_clean()


@pytest.mark.django_db
class TestEventCommentReactionModel:
    def test_create_reaction(self, test_user):
        event = Event.objects.create(
            title="Test Event",
            start_datetime="2030-01-01T00:00:00Z",
            created_by=test_user,
        )
        comment = EventComment.objects.create(event=event, author=test_user, body="hi")
        reaction = EventCommentReaction.objects.create(
            comment=comment, user=test_user, emoji=ReactionEmoji.HEART
        )
        assert reaction.id is not None

    def test_unique_constraint(self, test_user):
        event = Event.objects.create(
            title="Test Event",
            start_datetime="2030-01-01T00:00:00Z",
            created_by=test_user,
        )
        comment = EventComment.objects.create(event=event, author=test_user, body="hi")
        EventCommentReaction.objects.create(
            comment=comment, user=test_user, emoji=ReactionEmoji.HEART
        )
        with pytest.raises(IntegrityError), transaction.atomic():
            EventCommentReaction.objects.create(
                comment=comment, user=test_user, emoji=ReactionEmoji.HEART
            )
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
cd backend && uv run pytest tests/test_event_comment_model.py -q
```

Expected: ImportError on `EventComment`, `EventCommentReaction`, `ReactionEmoji` — module doesn't exist yet.

- [ ] **Step 3: Create the model file**

Create `backend/community/models/comment.py`:

```python
"""Event comment and reaction models.

Comments attach to Events with one level of reply nesting (a reply cannot
have a reply). Reactions are emoji-toggles on comments. See the spec at
docs/superpowers/specs/2026-05-15-event-comments-reactions-design.md.
"""

from __future__ import annotations

import uuid

from django.core.exceptions import ValidationError
from django.db import models


class ReactionEmoji(models.TextChoices):
    HEART = "❤️", "Heart"
    JOY = "😂", "Joy"
    SEEDLING = "🌱", "Seedling"
    FIRE = "🔥", "Fire"
    THUMBS_UP = "👍", "Thumbs up"
    SOB = "😭", "Sob"


class EventComment(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    event = models.ForeignKey(
        "community.Event",
        on_delete=models.CASCADE,
        related_name="comments",
    )
    author = models.ForeignKey(
        "users.User",
        on_delete=models.PROTECT,
        related_name="event_comments",
    )
    parent = models.ForeignKey(
        "self",
        null=True,
        blank=True,
        on_delete=models.CASCADE,
        related_name="replies",
    )
    body = models.TextField(max_length=500)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    deleted_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        app_label = "community"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["event", "-created_at"]),
            models.Index(fields=["parent", "created_at"]),
        ]

    def clean(self) -> None:
        super().clean()
        if self.parent_id is not None and self.parent.parent_id is not None:
            raise ValidationError({"parent": "Replies cannot have replies (depth = 1)."})
        if self.parent_id is not None and self.parent.event_id != self.event_id:
            raise ValidationError({"parent": "Reply must be in the same event as its parent."})

    @property
    def is_deleted(self) -> bool:
        return self.deleted_at is not None

    def __str__(self) -> str:
        return f"Comment {self.id} on event {self.event_id}"


class EventCommentReaction(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    comment = models.ForeignKey(
        EventComment,
        on_delete=models.CASCADE,
        related_name="reactions",
    )
    user = models.ForeignKey(
        "users.User",
        on_delete=models.CASCADE,
    )
    emoji = models.CharField(
        max_length=8,
        choices=ReactionEmoji.choices,
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        app_label = "community"
        constraints = [
            models.UniqueConstraint(
                fields=["comment", "user", "emoji"],
                name="unique_comment_user_emoji_reaction",
            ),
        ]
        indexes = [
            models.Index(fields=["comment", "emoji"]),
        ]

    def __str__(self) -> str:
        return f"{self.emoji} by {self.user_id} on comment {self.comment_id}"
```

- [ ] **Step 4: Re-export from the models package**

Edit `backend/community/models/__init__.py`. After the existing poll import (around line 33), add:

```python
from community.models.comment import EventComment, EventCommentReaction, ReactionEmoji
```

In the `__all__` list (lines 76–78ish), add a new comment-grouped block matching the existing style:

```python
__all__ = [
    # ... existing entries ...
    # poll
    "EventPoll",
    "PollOption",
    "PollVote",
    # comment
    "EventComment",
    "EventCommentReaction",
    "ReactionEmoji",
    # ... rest ...
]
```

- [ ] **Step 5: Run the model tests**

Run:
```bash
cd backend && uv run pytest tests/test_event_comment_model.py -q
```

Expected: all four tests pass. If `test_reply_to_top_level_comment` fails on `full_clean` because of the `parent.parent_id` lookup on an unsaved parent, that means `clean()` needs the parent to be saved first — the test creates `parent` via `objects.create` so it should be saved.

- [ ] **Step 6: Run typecheck + lint**

Run:
```bash
make agent-typecheck
make agent-lint
```

Expected: both pass.

- [ ] **Step 7: Commit**

```bash
git add backend/community/models/comment.py backend/community/models/__init__.py backend/tests/test_event_comment_model.py
git commit -m "$(cat <<'EOF'
feat(comments): EventComment and EventCommentReaction models

Adds two new models in the community app:
  - EventComment: top-level + one-level-deep replies, soft-delete,
    application-level reply-depth enforcement.
  - EventCommentReaction: (comment, user, emoji) uniqueness on a
    six-emoji whitelist.

Wired into community.models __all__. Migration generated next.
EOF
)"
```

---

## Task 3: Migration

**Files:**
- Create: `backend/community/migrations/00XX_event_comment_eventcommentreaction.py` (generated)

- [ ] **Step 1: Generate the migration**

Run:
```bash
cd /Users/leahpeker/development/pda-worktrees/spec-event-comments-reactions
make migrate
```

This runs `makemigrations users community` followed by `migrate`. It creates a migration file under `backend/community/migrations/` numbered after the highest existing migration. Confirm the file appears under `backend/community/migrations/` (a recent `ls -t backend/community/migrations/ | head -3` should show it).

- [ ] **Step 2: Inspect the generated migration**

Open the new file. Verify:
- Both `EventComment` and `EventCommentReaction` are in `operations`.
- The `UniqueConstraint` named `unique_comment_user_emoji_reaction` is present on `EventCommentReaction`.
- Both indexes are present (one on `EventComment`, one on `EventCommentReaction`).
- Dependencies include the latest `users` migration and the latest `community` migration prior to this one.

If anything is missing, fix the model and regenerate.

- [ ] **Step 3: Confirm migrate ran clean**

Run:
```bash
cd backend && uv run python manage.py showmigrations community | tail -5
```

Expected: the new migration shows `[X]` (applied).

- [ ] **Step 4: Run the model tests against the migrated DB**

Run:
```bash
cd backend && uv run pytest tests/test_event_comment_model.py -q
```

Expected: still pass.

- [ ] **Step 5: Commit**

```bash
git add backend/community/migrations/
git commit -m "$(cat <<'EOF'
feat(comments): migration for EventComment + EventCommentReaction

Reversible. No data backfill.
EOF
)"
```

---

## Task 4: Schemas

**Files:**
- Create: `backend/community/_event_comment_schemas.py`

- [ ] **Step 1: Write the schemas**

Create `backend/community/_event_comment_schemas.py`:

```python
"""Pydantic schemas for the event comments API."""

from __future__ import annotations

from datetime import datetime
from typing import Literal

from ninja import Field, Schema


class CommentReactionSummaryOut(Schema):
    emoji: str
    count: int
    reacted_by_me: bool


class EventCommentReplyOut(Schema):
    id: str
    author_id: str
    author_display_name: str
    author_photo_url: str
    body: str  # "" when is_deleted is True
    is_deleted: bool
    created_at: datetime
    reactions: list[CommentReactionSummaryOut]
    can_delete: bool


class EventCommentOut(EventCommentReplyOut):
    replies: list[EventCommentReplyOut]


class EventCommentListOut(Schema):
    items: list[EventCommentOut]
    can_post: bool
    cannot_post_reason: Literal["login_required", "rsvp_required"] | None = None


class CommentBodyIn(Schema):
    body: str = Field(..., min_length=1, max_length=500)


class ReactionToggleIn(Schema):
    emoji: str
```

Notes:
- `author_photo_url` is included even though the spec did not call it out explicitly; the existing `_event_out` pattern returns photo URLs for users and the FE renders avatars. Inferring from spec section "Comment row: avatar (existing user avatar component)".
- `can_post` and `cannot_post_reason` are computed per-request in the list endpoint.

- [ ] **Step 2: Sanity-check imports**

Run:
```bash
cd backend && uv run python -c "from community._event_comment_schemas import EventCommentOut, EventCommentListOut, CommentBodyIn, ReactionToggleIn; print('ok')"
```

Expected: prints `ok`.

- [ ] **Step 3: Run typecheck + lint**

```bash
make agent-typecheck
make agent-lint
```

Expected: both pass.

- [ ] **Step 4: Commit**

```bash
git add backend/community/_event_comment_schemas.py
git commit -m "$(cat <<'EOF'
feat(comments): pydantic schemas for the comments API

CommentReactionSummaryOut + EventCommentOut + EventCommentListOut
+ Input schemas (CommentBodyIn, ReactionToggleIn).
EOF
)"
```

---

## Task 5: Router skeleton and GET endpoint

**Files:**
- Create: `backend/community/_event_comments.py`
- Modify: `backend/community/api.py` — mount the new router

Build the list endpoint first (read-only, no rate limit), wire it through the API, and verify it returns an empty list for an event with no comments.

- [ ] **Step 1: Write the failing test — GET returns empty list with `can_post=False` for unauthed**

Create `backend/tests/test_event_comments.py`:

```python
"""End-to-end tests for the event comments API."""

import json

import pytest

from community.models import Event, EventRSVP, RSVPStatus
from tests.conftest import future_iso


@pytest.fixture
def event(db, test_user):
    return Event.objects.create(
        title="Test Event",
        start_datetime=future_iso(days=30),
        created_by=test_user,
    )


@pytest.mark.django_db
class TestGetComments:
    def test_get_empty_unauthed(self, api_client, event):
        response = api_client.get(f"/api/community/events/{event.id}/comments/")
        assert response.status_code == 200, response.content
        body = response.json()
        assert body["items"] == []
        assert body["can_post"] is False
        assert body["cannot_post_reason"] == "login_required"
```

- [ ] **Step 2: Run the test to verify it fails**

Run:
```bash
cd backend && uv run pytest tests/test_event_comments.py::TestGetComments::test_get_empty_unauthed -q
```

Expected: 404 (endpoint doesn't exist).

- [ ] **Step 3: Create the router file with the GET endpoint**

Create `backend/community/_event_comments.py`:

```python
"""EventComment endpoints — list, post, reply, delete, react."""

from __future__ import annotations

from uuid import UUID

from config.ratelimit import rate_limit
from django.db import transaction
from django.utils import timezone
from ninja import Router
from ninja.responses import Status
from ninja_jwt.authentication import JWTAuth
from users.permissions import PermissionKey

from community._event_comment_schemas import (
    CommentBodyIn,
    CommentReactionSummaryOut,
    EventCommentListOut,
    EventCommentOut,
    EventCommentReplyOut,
    ReactionToggleIn,
)
from community._events import _enforce_event_read_visibility
from community._shared import ErrorOut, _authenticated_user, _optional_jwt
from community._validation import Code, raise_validation
from community.models import (
    Event,
    EventComment,
    EventCommentReaction,
    EventRSVP,
    ReactionEmoji,
)

router = Router()


# ---------- helpers ----------


def _viewer_has_rsvp(event: Event, user) -> bool:
    if user is None:
        return False
    return EventRSVP.objects.filter(event=event, user=user).exists()


def _can_delete_comment(event: Event, comment: EventComment, user) -> bool:
    """Authors can always delete their own; creator / co-host / MANAGE_EVENTS can delete others'."""
    if user is None:
        return False
    if comment.author_id == user.pk:
        return True
    if user.has_permission(PermissionKey.MANAGE_EVENTS):
        return True
    if event.created_by_id == user.pk:
        return True
    return event.co_hosts.filter(pk=user.pk).exists()


def _reactions_summary(
    reactions: list[EventCommentReaction], viewer_id
) -> list[CommentReactionSummaryOut]:
    """Aggregate prefetched reactions into per-emoji counts + reacted_by_me."""
    by_emoji: dict[str, dict] = {}
    for r in reactions:
        bucket = by_emoji.setdefault(r.emoji, {"count": 0, "reacted_by_me": False})
        bucket["count"] += 1
        if viewer_id is not None and str(r.user_id) == str(viewer_id):
            bucket["reacted_by_me"] = True
    return [
        CommentReactionSummaryOut(emoji=e, count=v["count"], reacted_by_me=v["reacted_by_me"])
        for e, v in by_emoji.items()
    ]


def _comment_reply_out(
    comment: EventComment, event: Event, viewer
) -> EventCommentReplyOut:
    is_deleted = comment.deleted_at is not None
    reactions = (
        []
        if is_deleted
        else _reactions_summary(
            list(comment.reactions.all()),
            viewer.pk if viewer else None,
        )
    )
    return EventCommentReplyOut(
        id=str(comment.id),
        author_id=str(comment.author_id),
        author_display_name=comment.author.display_name or comment.author.phone_number,
        author_photo_url=_safe_photo_url(comment.author),
        body="" if is_deleted else comment.body,
        is_deleted=is_deleted,
        created_at=comment.created_at,
        reactions=reactions,
        can_delete=_can_delete_comment(event, comment, viewer),
    )


def _comment_out(comment: EventComment, event: Event, viewer) -> EventCommentOut:
    reply_list = sorted(comment.replies.all(), key=lambda r: r.created_at)
    base = _comment_reply_out(comment, event, viewer)
    return EventCommentOut(
        **base.dict(),
        replies=[_comment_reply_out(r, event, viewer) for r in reply_list],
    )


def _safe_photo_url(user) -> str:
    """Match the codebase pattern of media_path() returning '' for falsy profile_photo."""
    from config.media_proxy import media_path

    return media_path(user.profile_photo)


def _build_list_out(event: Event, viewer) -> EventCommentListOut:
    comments = (
        EventComment.objects.filter(event=event, parent__isnull=True)
        .select_related("author")
        .prefetch_related("replies__author", "reactions", "replies__reactions")
        .order_by("-created_at")
    )
    can_post = viewer is not None and _viewer_has_rsvp(event, viewer)
    if viewer is None:
        reason = "login_required"
    elif not can_post:
        reason = "rsvp_required"
    else:
        reason = None
    return EventCommentListOut(
        items=[_comment_out(c, event, viewer) for c in comments],
        can_post=can_post,
        cannot_post_reason=reason,
    )


# ---------- endpoints ----------


@router.get(
    "/events/{event_id}/comments/",
    response={200: EventCommentListOut, 404: ErrorOut, 403: ErrorOut},
    auth=_optional_jwt,
)
def list_comments(request, event_id: UUID):
    try:
        event = (
            Event.objects.select_related("created_by")
            .prefetch_related("co_hosts", "invited_users")
            .get(id=event_id)
        )
    except Event.DoesNotExist:
        raise_validation(Code.Event.NOT_FOUND, status_code=404)
    auth_user = _authenticated_user(request.auth)
    _enforce_event_read_visibility(event, auth_user)
    return Status(200, _build_list_out(event, auth_user))
```

- [ ] **Step 4: Mount the router**

Edit `backend/community/api.py`. After the existing `from community._polls import ...` line (around line 31), add:

```python
from community._event_comments import router as event_comments_router
```

After the existing `router.add_router("", polls_router)` line (around line 56), add:

```python
router.add_router("", event_comments_router)
```

- [ ] **Step 5: Run the test to verify it now passes**

Run:
```bash
cd backend && uv run pytest tests/test_event_comments.py::TestGetComments::test_get_empty_unauthed -q
```

Expected: pass.

- [ ] **Step 6: Run lint + typecheck**

```bash
make agent-lint
make agent-typecheck
```

Expected: both pass.

- [ ] **Step 7: Commit**

```bash
git add backend/community/_event_comments.py backend/community/api.py backend/tests/test_event_comments.py
git commit -m "$(cat <<'EOF'
feat(comments): GET /events/{id}/comments/ endpoint

Lists top-level comments newest-first with replies (oldest-first within
a thread) and aggregated reactions. Respects existing event visibility
gate. Surfaces can_post + cannot_post_reason so the FE can render the
right composer state without a second call.
EOF
)"
```

---

## Task 6: POST top-level comment endpoint

**Files:**
- Modify: `backend/community/_event_comments.py`
- Modify: `backend/tests/test_event_comments.py`

- [ ] **Step 1: Write failing tests for POST behavior**

Append to `backend/tests/test_event_comments.py`:

```python
@pytest.fixture
def rsvp_user(db):
    from users.models import User

    return User.objects.create_user(
        phone_number="+12025550303",
        password="rsvppass123",
        display_name="RSVP Member",
    )


@pytest.fixture
def rsvp_headers(rsvp_user):
    from ninja_jwt.tokens import RefreshToken

    refresh = RefreshToken.for_user(rsvp_user)
    return {"HTTP_AUTHORIZATION": f"Bearer {refresh.access_token}"}


@pytest.fixture
def event_with_rsvp(db, event, rsvp_user):
    EventRSVP.objects.create(event=event, user=rsvp_user, status=RSVPStatus.YES)
    return event


@pytest.mark.django_db
class TestPostComment:
    def test_post_requires_auth(self, api_client, event):
        response = api_client.post(
            f"/api/community/events/{event.id}/comments/",
            data=json.dumps({"body": "hi"}),
            content_type="application/json",
        )
        assert response.status_code == 401

    def test_post_requires_rsvp(self, api_client, auth_headers, event):
        response = api_client.post(
            f"/api/community/events/{event.id}/comments/",
            data=json.dumps({"body": "hi"}),
            content_type="application/json",
            **auth_headers,
        )
        assert response.status_code == 403
        assert response.json()["detail"][0]["code"] == "comment.rsvp_required"

    def test_post_creates_comment(self, api_client, rsvp_headers, event_with_rsvp):
        response = api_client.post(
            f"/api/community/events/{event_with_rsvp.id}/comments/",
            data=json.dumps({"body": "first comment"}),
            content_type="application/json",
            **rsvp_headers,
        )
        assert response.status_code == 201, response.content
        body = response.json()
        assert body["body"] == "first comment"
        assert body["is_deleted"] is False
        assert body["replies"] == []
        assert body["reactions"] == []
        assert body["can_delete"] is True  # author can delete

    def test_post_rejects_empty_body(self, api_client, rsvp_headers, event_with_rsvp):
        response = api_client.post(
            f"/api/community/events/{event_with_rsvp.id}/comments/",
            data=json.dumps({"body": ""}),
            content_type="application/json",
            **rsvp_headers,
        )
        assert response.status_code == 422

    def test_post_rejects_oversize_body(self, api_client, rsvp_headers, event_with_rsvp):
        response = api_client.post(
            f"/api/community/events/{event_with_rsvp.id}/comments/",
            data=json.dumps({"body": "x" * 501}),
            content_type="application/json",
            **rsvp_headers,
        )
        assert response.status_code == 422
```

- [ ] **Step 2: Run tests to confirm failures**

Run:
```bash
cd backend && uv run pytest tests/test_event_comments.py::TestPostComment -q
```

Expected: 404 or method-not-allowed (endpoint not implemented).

- [ ] **Step 3: Add POST endpoint to the router**

Append to `backend/community/_event_comments.py`:

```python
def _require_rsvp_for_post(event: Event, user) -> None:
    if not _viewer_has_rsvp(event, user):
        raise_validation(Code.Comment.RSVP_REQUIRED, status_code=403)


@router.post(
    "/events/{event_id}/comments/",
    response={201: EventCommentOut, 403: ErrorOut, 404: ErrorOut, 422: ErrorOut, 429: ErrorOut},
    auth=JWTAuth(),
)
@rate_limit(key_func=lambda r: str(r.auth.pk), rate="10/m")
def post_comment(request, event_id: UUID, payload: CommentBodyIn):
    try:
        event = (
            Event.objects.select_related("created_by")
            .prefetch_related("co_hosts", "invited_users")
            .get(id=event_id)
        )
    except Event.DoesNotExist:
        raise_validation(Code.Event.NOT_FOUND, status_code=404)
    user = request.auth
    _enforce_event_read_visibility(event, user)
    _require_rsvp_for_post(event, user)
    with transaction.atomic():
        comment = EventComment.objects.create(
            event=event, author=user, body=payload.body
        )
    return Status(201, _comment_out(comment, event, user))
```

- [ ] **Step 4: Run tests**

Run:
```bash
cd backend && uv run pytest tests/test_event_comments.py::TestPostComment -q
```

Expected: all pass.

- [ ] **Step 5: Lint + typecheck**

```bash
make agent-lint
make agent-typecheck
```

Expected: both pass.

- [ ] **Step 6: Commit**

```bash
git add backend/community/_event_comments.py backend/tests/test_event_comments.py
git commit -m "$(cat <<'EOF'
feat(comments): POST /events/{id}/comments/ endpoint

Authed + RSVP-gated. Returns 403 (comment.rsvp_required) when the
viewer has no EventRSVP on the event. Body min/max length enforced by
the Pydantic schema (1..=500 chars). Rate limit 10/m per user.
EOF
)"
```

---

## Task 7: POST reply endpoint

**Files:**
- Modify: `backend/community/_event_comments.py`
- Modify: `backend/tests/test_event_comments.py`

- [ ] **Step 1: Write failing tests for reply behavior**

Append to `backend/tests/test_event_comments.py`:

```python
@pytest.mark.django_db
class TestPostReply:
    def test_reply_to_top_level_comment(
        self, api_client, rsvp_headers, event_with_rsvp, rsvp_user
    ):
        parent = EventComment.objects.create(
            event=event_with_rsvp, author=rsvp_user, body="parent"
        )
        response = api_client.post(
            f"/api/community/events/{event_with_rsvp.id}/comments/{parent.id}/replies/",
            data=json.dumps({"body": "reply"}),
            content_type="application/json",
            **rsvp_headers,
        )
        assert response.status_code == 201, response.content
        # The reply itself is returned (shape: EventCommentReplyOut)
        body = response.json()
        assert body["body"] == "reply"
        assert body["is_deleted"] is False

    def test_reply_to_reply_fails_422(
        self, api_client, rsvp_headers, event_with_rsvp, rsvp_user
    ):
        parent = EventComment.objects.create(
            event=event_with_rsvp, author=rsvp_user, body="parent"
        )
        reply = EventComment.objects.create(
            event=event_with_rsvp, author=rsvp_user, body="reply", parent=parent
        )
        response = api_client.post(
            f"/api/community/events/{event_with_rsvp.id}/comments/{reply.id}/replies/",
            data=json.dumps({"body": "nested"}),
            content_type="application/json",
            **rsvp_headers,
        )
        assert response.status_code == 422
        assert response.json()["detail"][0]["code"] == "comment.reply_depth_exceeded"

    def test_reply_to_deleted_parent_404(
        self, api_client, rsvp_headers, event_with_rsvp, rsvp_user
    ):
        parent = EventComment.objects.create(
            event=event_with_rsvp, author=rsvp_user, body="parent"
        )
        parent.deleted_at = timezone.now()
        parent.save(update_fields=["deleted_at"])
        response = api_client.post(
            f"/api/community/events/{event_with_rsvp.id}/comments/{parent.id}/replies/",
            data=json.dumps({"body": "reply"}),
            content_type="application/json",
            **rsvp_headers,
        )
        assert response.status_code == 404
```

Add `from django.utils import timezone` near the top of the test file if it's not already present.

- [ ] **Step 2: Run tests**

Expected: failures (endpoint missing).

- [ ] **Step 3: Add reply endpoint**

Append to `backend/community/_event_comments.py`:

```python
@router.post(
    "/events/{event_id}/comments/{comment_id}/replies/",
    response={
        201: EventCommentReplyOut,
        403: ErrorOut,
        404: ErrorOut,
        422: ErrorOut,
        429: ErrorOut,
    },
    auth=JWTAuth(),
)
@rate_limit(key_func=lambda r: str(r.auth.pk), rate="10/m")
def post_reply(request, event_id: UUID, comment_id: UUID, payload: CommentBodyIn):
    try:
        event = (
            Event.objects.select_related("created_by")
            .prefetch_related("co_hosts", "invited_users")
            .get(id=event_id)
        )
    except Event.DoesNotExist:
        raise_validation(Code.Event.NOT_FOUND, status_code=404)
    user = request.auth
    _enforce_event_read_visibility(event, user)
    _require_rsvp_for_post(event, user)
    try:
        parent = EventComment.objects.get(id=comment_id, event=event)
    except EventComment.DoesNotExist:
        raise_validation(Code.Comment.NOT_FOUND, status_code=404)
    if parent.deleted_at is not None:
        raise_validation(Code.Comment.NOT_FOUND, status_code=404)
    if parent.parent_id is not None:
        raise_validation(Code.Comment.REPLY_DEPTH_EXCEEDED, status_code=422)
    with transaction.atomic():
        reply = EventComment.objects.create(
            event=event, author=user, body=payload.body, parent=parent
        )
    return Status(201, _comment_reply_out(reply, event, user))
```

- [ ] **Step 4: Run tests**

```bash
cd backend && uv run pytest tests/test_event_comments.py::TestPostReply -q
```

Expected: pass.

- [ ] **Step 5: Lint + typecheck + commit**

```bash
make agent-lint
make agent-typecheck
git add backend/community/_event_comments.py backend/tests/test_event_comments.py
git commit -m "$(cat <<'EOF'
feat(comments): POST /events/{id}/comments/{id}/replies/ endpoint

Adds one-level replies. Rejects reply-to-reply with
comment.reply_depth_exceeded (422). Treats soft-deleted parents as 404.
Notifications wiring comes in PR 2.
EOF
)"
```

---

## Task 8: DELETE endpoint with moderation

**Files:**
- Modify: `backend/community/_event_comments.py`
- Modify: `backend/tests/test_event_comments.py`

- [ ] **Step 1: Write failing tests**

Append to `backend/tests/test_event_comments.py`:

```python
@pytest.fixture
def admin_user(db):
    from users.models import Role, User

    user = User.objects.create_user(
        phone_number="+12025550404",
        password="adminpass123",
        display_name="Admin",
    )
    admin_role, _ = Role.objects.get_or_create(name="admin", defaults={"is_default": True})
    user.roles.add(admin_role)
    return user


@pytest.fixture
def admin_headers(admin_user):
    from ninja_jwt.tokens import RefreshToken

    refresh = RefreshToken.for_user(admin_user)
    return {"HTTP_AUTHORIZATION": f"Bearer {refresh.access_token}"}


@pytest.mark.django_db
class TestDeleteComment:
    def test_author_can_delete_own(
        self, api_client, rsvp_headers, event_with_rsvp, rsvp_user
    ):
        comment = EventComment.objects.create(
            event=event_with_rsvp, author=rsvp_user, body="mine"
        )
        response = api_client.delete(
            f"/api/community/events/{event_with_rsvp.id}/comments/{comment.id}/",
            **rsvp_headers,
        )
        assert response.status_code == 204
        comment.refresh_from_db()
        assert comment.deleted_at is not None

    def test_other_rsvper_cannot_delete(
        self, api_client, event_with_rsvp, test_user, auth_headers
    ):
        # The auth_headers fixture's test_user has no RSVP here, so first add one
        EventRSVP.objects.create(event=event_with_rsvp, user=test_user, status=RSVPStatus.YES)
        # And comment was authored by event creator (test_user), but the request
        # comes from the RSVP'd test_user — wait, same user. Use a third user.
        from users.models import User
        from ninja_jwt.tokens import RefreshToken

        author = User.objects.create_user(
            phone_number="+12025550505",
            password="authorpass",
            display_name="Author",
        )
        EventRSVP.objects.create(event=event_with_rsvp, user=author, status=RSVPStatus.YES)
        comment = EventComment.objects.create(
            event=event_with_rsvp, author=author, body="theirs"
        )
        response = api_client.delete(
            f"/api/community/events/{event_with_rsvp.id}/comments/{comment.id}/",
            **auth_headers,
        )
        assert response.status_code == 403

    def test_event_creator_can_delete_others(
        self, api_client, auth_headers, event, rsvp_user
    ):
        # event.created_by is test_user (auth_headers); comment is by rsvp_user
        comment = EventComment.objects.create(
            event=event, author=rsvp_user, body="theirs"
        )
        response = api_client.delete(
            f"/api/community/events/{event.id}/comments/{comment.id}/",
            **auth_headers,
        )
        assert response.status_code == 204
        comment.refresh_from_db()
        assert comment.deleted_at is not None

    def test_admin_can_delete_others(
        self, api_client, admin_headers, event, rsvp_user
    ):
        comment = EventComment.objects.create(
            event=event, author=rsvp_user, body="theirs"
        )
        response = api_client.delete(
            f"/api/community/events/{event.id}/comments/{comment.id}/",
            **admin_headers,
        )
        assert response.status_code == 204

    def test_double_delete_is_idempotent(
        self, api_client, rsvp_headers, event_with_rsvp, rsvp_user
    ):
        comment = EventComment.objects.create(
            event=event_with_rsvp, author=rsvp_user, body="mine"
        )
        first = api_client.delete(
            f"/api/community/events/{event_with_rsvp.id}/comments/{comment.id}/",
            **rsvp_headers,
        )
        second = api_client.delete(
            f"/api/community/events/{event_with_rsvp.id}/comments/{comment.id}/",
            **rsvp_headers,
        )
        assert first.status_code == 204
        assert second.status_code == 204
```

If the `Role` import / model lookup doesn't match (different field name etc.), update the `admin_user` fixture to use whatever bootstrap mechanism `users` actually exposes. Inspect `backend/tests/conftest.py` for any existing admin-user fixture before re-rolling this.

- [ ] **Step 2: Run tests — verify failures**

```bash
cd backend && uv run pytest tests/test_event_comments.py::TestDeleteComment -q
```

- [ ] **Step 3: Add DELETE endpoint**

Append to `backend/community/_event_comments.py`:

```python
@router.delete(
    "/events/{event_id}/comments/{comment_id}/",
    response={204: None, 403: ErrorOut, 404: ErrorOut, 429: ErrorOut},
    auth=JWTAuth(),
)
@rate_limit(key_func=lambda r: str(r.auth.pk), rate="10/m")
def delete_comment(request, event_id: UUID, comment_id: UUID):
    try:
        event = (
            Event.objects.select_related("created_by")
            .prefetch_related("co_hosts", "invited_users")
            .get(id=event_id)
        )
    except Event.DoesNotExist:
        raise_validation(Code.Event.NOT_FOUND, status_code=404)
    user = request.auth
    _enforce_event_read_visibility(event, user)
    try:
        comment = EventComment.objects.get(id=comment_id, event=event)
    except EventComment.DoesNotExist:
        raise_validation(Code.Comment.NOT_FOUND, status_code=404)
    if not _can_delete_comment(event, comment, user):
        raise_validation(Code.Comment.PERM_DENIED, status_code=403, action="delete_comment")
    if comment.deleted_at is None:
        with transaction.atomic():
            comment.deleted_at = timezone.now()
            comment.save(update_fields=["deleted_at", "updated_at"])
    return Status(204, None)
```

- [ ] **Step 4: Run tests + lint + typecheck**

```bash
cd backend && uv run pytest tests/test_event_comments.py::TestDeleteComment -q
make agent-lint
make agent-typecheck
```

- [ ] **Step 5: Commit**

```bash
git add backend/community/_event_comments.py backend/tests/test_event_comments.py
git commit -m "$(cat <<'EOF'
feat(comments): DELETE /events/{id}/comments/{id}/ endpoint

Soft-delete. Author, event creator, co-host, or MANAGE_EVENTS admin
may delete. Idempotent (second delete returns 204). Replies under a
deleted parent stay visible (the API returns body="" for the deleted
row only).
EOF
)"
```

---

## Task 9: Reaction toggle endpoint

**Files:**
- Modify: `backend/community/_event_comments.py`
- Modify: `backend/tests/test_event_comments.py`

- [ ] **Step 1: Write failing tests**

Append to `backend/tests/test_event_comments.py`:

```python
@pytest.mark.django_db
class TestReactionToggle:
    def test_first_toggle_creates(
        self, api_client, rsvp_headers, event_with_rsvp, rsvp_user
    ):
        comment = EventComment.objects.create(
            event=event_with_rsvp, author=rsvp_user, body="hi"
        )
        response = api_client.post(
            f"/api/community/events/{event_with_rsvp.id}/comments/{comment.id}/reactions/",
            data=json.dumps({"emoji": "❤️"}),
            content_type="application/json",
            **rsvp_headers,
        )
        assert response.status_code == 200, response.content
        body = response.json()
        hearts = [r for r in body["reactions"] if r["emoji"] == "❤️"]
        assert len(hearts) == 1
        assert hearts[0]["count"] == 1
        assert hearts[0]["reacted_by_me"] is True

    def test_second_toggle_removes(
        self, api_client, rsvp_headers, event_with_rsvp, rsvp_user
    ):
        comment = EventComment.objects.create(
            event=event_with_rsvp, author=rsvp_user, body="hi"
        )
        EventCommentReaction.objects.create(
            comment=comment, user=rsvp_user, emoji="❤️"
        )
        response = api_client.post(
            f"/api/community/events/{event_with_rsvp.id}/comments/{comment.id}/reactions/",
            data=json.dumps({"emoji": "❤️"}),
            content_type="application/json",
            **rsvp_headers,
        )
        assert response.status_code == 200
        assert response.json()["reactions"] == []

    def test_stacking_different_emojis(
        self, api_client, rsvp_headers, event_with_rsvp, rsvp_user
    ):
        comment = EventComment.objects.create(
            event=event_with_rsvp, author=rsvp_user, body="hi"
        )
        api_client.post(
            f"/api/community/events/{event_with_rsvp.id}/comments/{comment.id}/reactions/",
            data=json.dumps({"emoji": "❤️"}),
            content_type="application/json",
            **rsvp_headers,
        )
        response = api_client.post(
            f"/api/community/events/{event_with_rsvp.id}/comments/{comment.id}/reactions/",
            data=json.dumps({"emoji": "🔥"}),
            content_type="application/json",
            **rsvp_headers,
        )
        emojis = {r["emoji"] for r in response.json()["reactions"]}
        assert emojis == {"❤️", "🔥"}

    def test_invalid_emoji(
        self, api_client, rsvp_headers, event_with_rsvp, rsvp_user
    ):
        comment = EventComment.objects.create(
            event=event_with_rsvp, author=rsvp_user, body="hi"
        )
        response = api_client.post(
            f"/api/community/events/{event_with_rsvp.id}/comments/{comment.id}/reactions/",
            data=json.dumps({"emoji": "🦊"}),
            content_type="application/json",
            **rsvp_headers,
        )
        assert response.status_code == 422
        assert response.json()["detail"][0]["code"] == "comment.invalid_emoji"

    def test_reaction_requires_rsvp(self, api_client, auth_headers, event):
        # auth_headers is test_user, who created the event but did not RSVP
        comment = EventComment.objects.create(event=event, author=event.created_by, body="hi")
        response = api_client.post(
            f"/api/community/events/{event.id}/comments/{comment.id}/reactions/",
            data=json.dumps({"emoji": "❤️"}),
            content_type="application/json",
            **auth_headers,
        )
        assert response.status_code == 403

    def test_rate_limit_kicks_in(
        self, api_client, rsvp_headers, event_with_rsvp, rsvp_user
    ):
        """11th write in 60s should 429. Toggles back-and-forth to avoid the
        unique-constraint blocking the second create — toggle on, off, on, off..."""
        from django.core.cache import cache
        cache.clear()
        comment = EventComment.objects.create(
            event=event_with_rsvp, author=rsvp_user, body="hi"
        )
        url = f"/api/community/events/{event_with_rsvp.id}/comments/{comment.id}/reactions/"
        for _ in range(10):
            r = api_client.post(
                url,
                data=json.dumps({"emoji": "❤️"}),
                content_type="application/json",
                **rsvp_headers,
            )
            assert r.status_code == 200, r.content
        # 11th request hits the limit
        r = api_client.post(
            url,
            data=json.dumps({"emoji": "❤️"}),
            content_type="application/json",
            **rsvp_headers,
        )
        assert r.status_code == 429
        assert r.json()["detail"][0]["code"] == "rate.limited"
```

- [ ] **Step 2: Run tests**

Expected: failures.

- [ ] **Step 3: Add the reaction endpoint**

Append to `backend/community/_event_comments.py`:

```python
_VALID_EMOJIS = {e.value for e in ReactionEmoji}


@router.post(
    "/events/{event_id}/comments/{comment_id}/reactions/",
    response={
        200: EventCommentOut,
        403: ErrorOut,
        404: ErrorOut,
        422: ErrorOut,
        429: ErrorOut,
    },
    auth=JWTAuth(),
)
@rate_limit(key_func=lambda r: str(r.auth.pk), rate="10/m")
def toggle_reaction(request, event_id: UUID, comment_id: UUID, payload: ReactionToggleIn):
    try:
        event = (
            Event.objects.select_related("created_by")
            .prefetch_related("co_hosts", "invited_users")
            .get(id=event_id)
        )
    except Event.DoesNotExist:
        raise_validation(Code.Event.NOT_FOUND, status_code=404)
    user = request.auth
    _enforce_event_read_visibility(event, user)
    _require_rsvp_for_post(event, user)
    if payload.emoji not in _VALID_EMOJIS:
        raise_validation(Code.Comment.INVALID_EMOJI, status_code=422)
    try:
        comment = EventComment.objects.get(id=comment_id, event=event)
    except EventComment.DoesNotExist:
        raise_validation(Code.Comment.NOT_FOUND, status_code=404)
    if comment.deleted_at is not None:
        raise_validation(Code.Comment.NOT_FOUND, status_code=404)
    with transaction.atomic():
        existing = EventCommentReaction.objects.filter(
            comment=comment, user=user, emoji=payload.emoji
        ).first()
        if existing:
            existing.delete()
        else:
            EventCommentReaction.objects.create(
                comment=comment, user=user, emoji=payload.emoji
            )
    # The toggle endpoint returns the parent top-level comment so the FE can
    # update either a top-level row (when comment is top-level) or the reply's
    # row (when comment is a reply). When it's a reply, we return the parent.
    target = comment if comment.parent_id is None else comment.parent
    target.refresh_from_db()
    # Prefetch the freshly-changed reactions for serialization.
    target = (
        EventComment.objects.select_related("author")
        .prefetch_related("replies__author", "reactions", "replies__reactions")
        .get(id=target.id)
    )
    return Status(200, _comment_out(target, event, user))
```

- [ ] **Step 4: Run tests, lint, typecheck**

```bash
cd backend && uv run pytest tests/test_event_comments.py::TestReactionToggle -q
make agent-lint
make agent-typecheck
```

- [ ] **Step 5: Commit**

```bash
git add backend/community/_event_comments.py backend/tests/test_event_comments.py
git commit -m "$(cat <<'EOF'
feat(comments): POST reactions toggle endpoint

Single endpoint POSTs the emoji to toggle; (comment, user, emoji)
unique constraint enforces idempotent on/off. Returns the updated
top-level EventCommentOut so the FE updates a single cache entry
whether the reaction was on a comment or a reply.

Whitelisted emojis: ❤️ 😂 🌱 🔥 👍 😭. Invalid emoji → 422
comment.invalid_emoji.
EOF
)"
```

---

## Task 10: Visibility cascade tests

**Files:**
- Modify: `backend/tests/test_event_comments.py`

Confirm that the existing `_enforce_event_read_visibility` correctly gates comments. No new endpoint code is needed — this task just adds the test that *proves* the cascade works.

- [ ] **Step 1: Add visibility tests**

Append to `backend/tests/test_event_comments.py`:

```python
from community.models import PageVisibility


@pytest.mark.django_db
class TestCommentVisibility:
    def test_invite_only_non_invitee_cannot_list(self, api_client, db, rsvp_user, rsvp_headers):
        creator = rsvp_user  # using rsvp_user as the event creator
        from users.models import User
        from ninja_jwt.tokens import RefreshToken

        stranger = User.objects.create_user(
            phone_number="+12025550606",
            password="strangerpass",
            display_name="Stranger",
        )
        refresh = RefreshToken.for_user(stranger)
        stranger_headers = {"HTTP_AUTHORIZATION": f"Bearer {refresh.access_token}"}
        event = Event.objects.create(
            title="Invite-only",
            start_datetime=future_iso(days=30),
            created_by=creator,
            visibility=PageVisibility.INVITE_ONLY,
        )
        response = api_client.get(
            f"/api/community/events/{event.id}/comments/",
            **stranger_headers,
        )
        # _can_see_invite_only returns False → _enforce_event_read_visibility
        # raises Code.Event.INVITE_ONLY with status 403.
        assert response.status_code == 403

    def test_invite_only_invitee_can_list(self, api_client, db, rsvp_user, rsvp_headers):
        creator = rsvp_user
        event = Event.objects.create(
            title="Invite-only",
            start_datetime=future_iso(days=30),
            created_by=creator,
            visibility=PageVisibility.INVITE_ONLY,
        )
        # rsvp_user is the creator, so they can always see
        response = api_client.get(
            f"/api/community/events/{event.id}/comments/",
            **rsvp_headers,
        )
        assert response.status_code == 200
```

- [ ] **Step 2: Run tests**

```bash
cd backend && uv run pytest tests/test_event_comments.py::TestCommentVisibility -q
```

Expected: pass without further code changes — the cascade is already wired.

- [ ] **Step 3: Run the full comments suite**

```bash
cd backend && uv run pytest tests/test_event_comments.py tests/test_event_comment_model.py -q
```

Expected: all green.

- [ ] **Step 4: Lint + typecheck + commit**

```bash
make agent-lint
make agent-typecheck
git add backend/tests/test_event_comments.py
git commit -m "$(cat <<'EOF'
test(comments): visibility cascade on invite-only events

No production code change. Proves the existing
_enforce_event_read_visibility helper correctly gates comments on
invite-only events.
EOF
)"
```

---

## Task 11: Add `comment_count` to `EventOut`

**Files:**
- Modify: `backend/community/_event_schemas.py` — add field to `EventOut` and `EventListOut`
- Modify: `backend/community/_event_helpers.py:289-350` — annotate + return `comment_count`
- Modify: `backend/community/_events.py` — annotate the list query
- Modify: `backend/tests/test_events.py` (or wherever EventOut field assertions live) — add expectation

- [ ] **Step 1: Locate every EventOut serializer call site**

Run:
```bash
cd /Users/leahpeker/development/pda-worktrees/spec-event-comments-reactions
grep -rn "_event_out(" backend/community/ | head -20
grep -rn "EventOut(" backend/community/ | head -10
grep -rn "EventListOut(" backend/community/ | head -10
```

Note every caller. You'll need to ensure each call site's queryset is annotated with `comment_count`, OR you need to compute `comment_count` from `event.comments` on the fly. The simpler, safer pattern: **annotate at every list call site**, and `_event_out` reads either the annotation or falls back to a `.count()` query (acceptable for single-event reads).

- [ ] **Step 2: Add the field to schemas**

Edit `backend/community/_event_schemas.py`. Find the `class EventOut(Schema)` block and add `comment_count: int = 0` near the bottom of the field list (after `pending_cohost_invites` / before `my_pending_cohost_invite_id` — pick a position that keeps related fields together; alphabetical or by-section is fine).

Do the same for `EventListOut` if it has its own field list (it shares many fields with EventOut; check if it inherits or redeclares).

- [ ] **Step 3: Modify `_event_out` to populate the field**

Edit `backend/community/_event_helpers.py` at line 289 (`_event_out`). Add inside the function body, before the `return EventOut(...)`:

```python
comment_count = getattr(event, "comment_count", None)
if comment_count is None:
    comment_count = event.comments.filter(deleted_at__isnull=True).count()
```

Then in the `return EventOut(...)` call, add `comment_count=comment_count,` as a new keyword argument.

- [ ] **Step 4: Annotate the list queries**

Find every Event queryset that flows into a list response. Add to each:

```python
from django.db.models import Count, Q
# ...
qs = qs.annotate(
    comment_count=Count("comments", filter=Q(comments__deleted_at__isnull=True), distinct=True)
)
```

The `distinct=True` is important because combining `Count` with other prefetch annotations can double-count.

Specifically modify `_events.py:list_events` (around line 130–180). If there are other list endpoints (`my_events`, etc.), do them too.

- [ ] **Step 5: Write a test**

Add to `backend/tests/test_event_comments.py`:

```python
@pytest.mark.django_db
class TestEventOutCommentCount:
    def test_event_list_includes_comment_count(self, api_client, rsvp_headers, event_with_rsvp, rsvp_user):
        EventComment.objects.create(event=event_with_rsvp, author=rsvp_user, body="one")
        c2 = EventComment.objects.create(event=event_with_rsvp, author=rsvp_user, body="two")
        # Deleted comments do not count.
        c2.deleted_at = timezone.now()
        c2.save(update_fields=["deleted_at"])
        response = api_client.get(f"/api/community/events/", **rsvp_headers)
        assert response.status_code == 200
        # Find our event in the list and confirm comment_count == 1.
        events_data = response.json()
        # Adjust this lookup based on actual EventListOut shape — may be a list or {"items": [...]}.
        events_list = events_data if isinstance(events_data, list) else events_data.get("events", events_data)
        target = next(e for e in events_list if e["id"] == str(event_with_rsvp.id))
        assert target["comment_count"] == 1

    def test_event_detail_includes_comment_count(self, api_client, rsvp_headers, event_with_rsvp, rsvp_user):
        EventComment.objects.create(event=event_with_rsvp, author=rsvp_user, body="one")
        response = api_client.get(
            f"/api/community/events/{event_with_rsvp.id}/",
            **rsvp_headers,
        )
        assert response.status_code == 200
        assert response.json()["comment_count"] == 1
```

If the EventListOut shape is different from what's guessed in the test, adjust the lookup logic to match `_events.py:list_events`'s actual return structure.

- [ ] **Step 6: Run tests**

```bash
cd backend && uv run pytest tests/test_event_comments.py::TestEventOutCommentCount -q
```

Expected: both new tests pass.

Then run the broader event test suite to catch any existing tests that snapshot EventOut/EventListOut payloads:

```bash
cd backend && uv run pytest tests/ -k event -q
```

If any existing test fails because it asserted the full response shape and a new field appeared, update those assertions to include `comment_count` (or to ignore unknown fields). The new field has a default of `0` so most callers will see no behavior change.

- [ ] **Step 7: Lint + typecheck + commit**

```bash
make agent-lint
make agent-typecheck
git add backend/community/_event_schemas.py backend/community/_event_helpers.py backend/community/_events.py backend/tests/
git commit -m "$(cat <<'EOF'
feat(comments): comment_count on EventOut and EventListOut

Single annotated query in the list endpoint (Count with
deleted_at__isnull=True filter, distinct=True). Detail endpoint falls
back to a per-event count if the annotation isn't present.
EOF
)"
```

---

## Task 12: Regenerate frontend types + validation codes

**Files:**
- Modify: `frontend/src/api/types.gen.ts` (generated)
- Modify: `frontend/src/api/validationCodes.gen.ts` (generated)
- Modify: `frontend/src/api/validationCodes.ts` — add user-facing messages for `comment.*` codes

- [ ] **Step 1: Run the type generator**

Run:
```bash
cd /Users/leahpeker/development/pda-worktrees/spec-event-comments-reactions
make frontend-types
```

Expected: `types.gen.ts` and `validationCodes.gen.ts` update. New entries should include:
- `EventCommentOut`, `EventCommentReplyOut`, `EventCommentListOut`, `CommentBodyIn`, `ReactionToggleIn`, `CommentReactionSummaryOut`.
- New endpoint paths under `/api/community/events/{event_id}/comments/...`.
- New codes: `comment.not_found`, `comment.reply_depth_exceeded`, `comment.invalid_emoji`, `comment.rsvp_required`, `comment.perm_denied`, `comment.event_mismatch`.

If the generator fails, inspect output for clues — usually a backend syntax error or a `ty` typecheck failure that wasn't surfaced.

- [ ] **Step 2: Add user-facing messages**

Edit `frontend/src/api/validationCodes.ts`. In the `messageForCode` switch (or equivalent), add cases for each new code. Example wording (all lowercase per the frontend rule):

```ts
case 'comment.not_found':
  return 'comment not found';
case 'comment.reply_depth_exceeded':
  return "replies can't have replies";
case 'comment.invalid_emoji':
  return 'that emoji is not available';
case 'comment.rsvp_required':
  return 'rsvp to join the conversation';
case 'comment.perm_denied':
  return "you don't have permission to do that";
case 'comment.event_mismatch':
  return "that reply target isn't in this event";
```

If `validationCodes.ts` uses a different structure (e.g. an object map), match its existing pattern.

- [ ] **Step 3: Run frontend typecheck + lint**

```bash
make agent-frontend-typecheck
make agent-frontend-lint
```

Expected: both pass.

- [ ] **Step 4: Commit**

```bash
git add frontend/src/api/types.gen.ts frontend/src/api/validationCodes.gen.ts frontend/src/api/validationCodes.ts
git commit -m "$(cat <<'EOF'
feat(comments): regenerate frontend API types + add error messages

Picks up the new comment endpoints, schemas, and comment.* validation
codes from the OpenAPI/code generators.
EOF
)"
```

---

## Task 13: Frontend domain model + wire mapper

**Files:**
- Create: `frontend/src/models/eventComment.ts`
- Create: `frontend/src/api/eventCommentMapper.ts`

- [ ] **Step 1: Write the domain model**

Create `frontend/src/models/eventComment.ts`:

```ts
export const ReactionEmoji = {
  Heart: '❤️',
  Joy: '😂',
  Seedling: '🌱',
  Fire: '🔥',
  ThumbsUp: '👍',
  Sob: '😭',
} as const;

export type ReactionEmojiValue = (typeof ReactionEmoji)[keyof typeof ReactionEmoji];

export const REACTION_EMOJI_ORDER: ReactionEmojiValue[] = [
  ReactionEmoji.Heart,
  ReactionEmoji.Joy,
  ReactionEmoji.Seedling,
  ReactionEmoji.Fire,
  ReactionEmoji.ThumbsUp,
  ReactionEmoji.Sob,
];

export interface CommentReactionSummary {
  emoji: ReactionEmojiValue;
  count: number;
  reactedByMe: boolean;
}

export interface EventCommentReply {
  id: string;
  authorId: string;
  authorDisplayName: string;
  authorPhotoUrl: string;
  body: string;
  isDeleted: boolean;
  createdAt: string; // ISO string
  reactions: CommentReactionSummary[];
  canDelete: boolean;
}

export interface EventComment extends EventCommentReply {
  replies: EventCommentReply[];
}

export type CannotPostReason = 'login_required' | 'rsvp_required';

export interface EventCommentList {
  items: EventComment[];
  canPost: boolean;
  cannotPostReason: CannotPostReason | null;
}
```

- [ ] **Step 2: Write the wire mapper**

Create `frontend/src/api/eventCommentMapper.ts`:

```ts
import type { components } from '@/api/types.gen';
import type {
  CommentReactionSummary,
  EventComment,
  EventCommentList,
  EventCommentReply,
  ReactionEmojiValue,
} from '@/models/eventComment';

type WireSummary = components['schemas']['CommentReactionSummaryOut'];
type WireReply = components['schemas']['EventCommentReplyOut'];
type WireComment = components['schemas']['EventCommentOut'];
type WireList = components['schemas']['EventCommentListOut'];

function mapSummary(wire: WireSummary): CommentReactionSummary {
  return {
    emoji: wire.emoji as ReactionEmojiValue,
    count: wire.count,
    reactedByMe: wire.reacted_by_me,
  };
}

export function mapReply(wire: WireReply): EventCommentReply {
  return {
    id: wire.id,
    authorId: wire.author_id,
    authorDisplayName: wire.author_display_name,
    authorPhotoUrl: wire.author_photo_url,
    body: wire.body,
    isDeleted: wire.is_deleted,
    createdAt: wire.created_at,
    reactions: wire.reactions.map(mapSummary),
    canDelete: wire.can_delete,
  };
}

export function mapComment(wire: WireComment): EventComment {
  return {
    ...mapReply(wire),
    replies: wire.replies.map(mapReply),
  };
}

export function mapCommentList(wire: WireList): EventCommentList {
  return {
    items: wire.items.map(mapComment),
    canPost: wire.can_post,
    cannotPostReason: wire.cannot_post_reason ?? null,
  };
}
```

If `components['schemas']` is not the actual type-import shape (check `types.gen.ts`), adjust the imports to match. Other mappers in this codebase (e.g. `eventPollMapper.ts`) show the canonical shape.

- [ ] **Step 3: Frontend typecheck**

```bash
make agent-frontend-typecheck
```

Expected: pass. If `components['schemas']['EventCommentOut']` is missing, the type generator didn't pick up the schema — go back to Task 12.

- [ ] **Step 4: Commit**

```bash
git add frontend/src/models/eventComment.ts frontend/src/api/eventCommentMapper.ts
git commit -m "$(cat <<'EOF'
feat(comments): frontend types + wire mapper

Domain types (camelCase) + mapper from generated WireXyz types.
Mirrors the EventPoll mapper pattern.
EOF
)"
```

---

## Task 14: TanStack hooks

**Files:**
- Create: `frontend/src/api/eventComments.ts`
- Create: `frontend/src/api/eventComments.test.ts`

- [ ] **Step 1: Write the failing test for `useEventComments`**

Create `frontend/src/api/eventComments.test.ts`:

```ts
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { renderHook, waitFor } from '@testing-library/react';
import { http, HttpResponse } from 'msw';
import { setupServer } from 'msw/node';
import { afterAll, afterEach, beforeAll, describe, expect, it } from 'vitest';

import { useEventComments } from './eventComments';

const eventId = '11111111-1111-1111-1111-111111111111';

const server = setupServer(
  http.get(`*/api/community/events/${eventId}/comments/`, () => {
    return HttpResponse.json({
      items: [],
      can_post: false,
      cannot_post_reason: 'login_required',
    });
  }),
);

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

function wrapper({ children }: { children: React.ReactNode }) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return <QueryClientProvider client={qc}>{children}</QueryClientProvider>;
}

describe('useEventComments', () => {
  it('maps the wire payload to the domain shape', async () => {
    const { result } = renderHook(() => useEventComments(eventId), { wrapper });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data).toEqual({
      items: [],
      canPost: false,
      cannotPostReason: 'login_required',
    });
  });
});
```

If `msw` is not yet a dependency, check `frontend/package.json` and the existing api tests for a different mocking convention (some codebases use `vi.mock('axios')` directly). If MSW is not installed, mock the api client module instead:

```ts
vi.mock('@/api/client', () => ({
  apiClient: { get: vi.fn().mockResolvedValue({ data: { items: [], can_post: false, cannot_post_reason: 'login_required' } }) },
}));
```

Pick whichever convention the existing `eventPolls.ts` tests use (run `ls frontend/src/api/*.test.*` to see them).

- [ ] **Step 2: Run the test — confirm failure**

```bash
cd frontend && pnpm exec vitest run src/api/eventComments.test.ts
```

Expected: import failure on `./eventComments`.

- [ ] **Step 3: Implement the hooks file**

Create `frontend/src/api/eventComments.ts`:

```ts
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';

import { apiClient } from './client';
import { eventKeys } from './events';
import { mapComment, mapCommentList, mapReply } from './eventCommentMapper';
import type {
  EventComment,
  EventCommentList,
  EventCommentReply,
  ReactionEmojiValue,
} from '@/models/eventComment';

export const eventCommentKeys = {
  all: ['eventComments'] as const,
  list: (eventId: string) => [...eventCommentKeys.all, eventId] as const,
};

export function useEventComments(eventId: string) {
  return useQuery({
    queryKey: eventCommentKeys.list(eventId),
    queryFn: async (): Promise<EventCommentList> => {
      const res = await apiClient.get(`/community/events/${eventId}/comments/`);
      return mapCommentList(res.data);
    },
    enabled: Boolean(eventId),
  });
}

interface PostCommentVars {
  body: string;
}

export function usePostComment(eventId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({ body }: PostCommentVars): Promise<EventComment> => {
      const res = await apiClient.post(
        `/community/events/${eventId}/comments/`,
        { body },
      );
      return mapComment(res.data);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: eventCommentKeys.list(eventId) });
      qc.invalidateQueries({ queryKey: eventKeys.detail(eventId) });
    },
  });
}

interface PostReplyVars {
  parentId: string;
  body: string;
}

export function usePostReply(eventId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({ parentId, body }: PostReplyVars): Promise<EventCommentReply> => {
      const res = await apiClient.post(
        `/community/events/${eventId}/comments/${parentId}/replies/`,
        { body },
      );
      return mapReply(res.data);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: eventCommentKeys.list(eventId) });
    },
  });
}

interface DeleteCommentVars {
  commentId: string;
}

export function useDeleteComment(eventId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({ commentId }: DeleteCommentVars) => {
      await apiClient.delete(`/community/events/${eventId}/comments/${commentId}/`);
    },
    onMutate: async ({ commentId }) => {
      await qc.cancelQueries({ queryKey: eventCommentKeys.list(eventId) });
      const prev = qc.getQueryData<EventCommentList>(eventCommentKeys.list(eventId));
      if (prev) {
        const next: EventCommentList = {
          ...prev,
          items: prev.items.map((c) =>
            c.id === commentId
              ? { ...c, isDeleted: true, body: '', reactions: [] }
              : {
                  ...c,
                  replies: c.replies.map((r) =>
                    r.id === commentId
                      ? { ...r, isDeleted: true, body: '', reactions: [] }
                      : r,
                  ),
                },
          ),
        };
        qc.setQueryData(eventCommentKeys.list(eventId), next);
      }
      return { prev };
    },
    onError: (_err, _vars, ctx) => {
      if (ctx?.prev) {
        qc.setQueryData(eventCommentKeys.list(eventId), ctx.prev);
      }
    },
    onSettled: () => {
      qc.invalidateQueries({ queryKey: eventCommentKeys.list(eventId) });
      qc.invalidateQueries({ queryKey: eventKeys.detail(eventId) });
    },
  });
}

interface ToggleReactionVars {
  commentId: string;
  emoji: ReactionEmojiValue;
}

export function useToggleReaction(eventId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({ commentId, emoji }: ToggleReactionVars): Promise<EventComment> => {
      const res = await apiClient.post(
        `/community/events/${eventId}/comments/${commentId}/reactions/`,
        { emoji },
      );
      return mapComment(res.data);
    },
    onMutate: async ({ commentId, emoji }) => {
      await qc.cancelQueries({ queryKey: eventCommentKeys.list(eventId) });
      const prev = qc.getQueryData<EventCommentList>(eventCommentKeys.list(eventId));
      if (prev) {
        const toggleOnRow = <T extends EventCommentReply>(row: T): T => {
          if (row.id !== commentId) return row;
          const existing = row.reactions.find((r) => r.emoji === emoji);
          let next = row.reactions.slice();
          if (existing && existing.reactedByMe) {
            next = next
              .map((r) =>
                r.emoji === emoji
                  ? { ...r, count: r.count - 1, reactedByMe: false }
                  : r,
              )
              .filter((r) => r.count > 0);
          } else if (existing) {
            next = next.map((r) =>
              r.emoji === emoji
                ? { ...r, count: r.count + 1, reactedByMe: true }
                : r,
            );
          } else {
            next = [...next, { emoji, count: 1, reactedByMe: true }];
          }
          return { ...row, reactions: next };
        };
        const nextList: EventCommentList = {
          ...prev,
          items: prev.items.map((c) => {
            const updated = toggleOnRow(c);
            return {
              ...updated,
              replies: updated.replies.map(toggleOnRow),
            };
          }),
        };
        qc.setQueryData(eventCommentKeys.list(eventId), nextList);
      }
      return { prev };
    },
    onError: (_err, _vars, ctx) => {
      if (ctx?.prev) {
        qc.setQueryData(eventCommentKeys.list(eventId), ctx.prev);
      }
    },
    onSettled: () => {
      qc.invalidateQueries({ queryKey: eventCommentKeys.list(eventId) });
    },
  });
}
```

Notes:
- `eventKeys.detail` should already be exported from `frontend/src/api/events.ts` (check for it — the cache key factory pattern is used elsewhere). If the exported name differs, adjust.
- `apiClient` is imported from `@/api/client` matching `eventPolls.ts`.

- [ ] **Step 4: Run the test**

```bash
cd frontend && pnpm exec vitest run src/api/eventComments.test.ts
```

Expected: pass.

- [ ] **Step 5: Frontend typecheck + lint**

```bash
make agent-frontend-typecheck
make agent-frontend-lint
```

Expected: both pass.

- [ ] **Step 6: Commit**

```bash
git add frontend/src/api/eventComments.ts frontend/src/api/eventComments.test.ts
git commit -m "$(cat <<'EOF'
feat(comments): TanStack hooks for comments + reactions

useEventComments (read), usePostComment, usePostReply,
useDeleteComment, useToggleReaction. Optimistic updates on delete
and reaction toggle; invalidate event detail cache on mutations
that change comment_count.
EOF
)"
```

---

## Task 15: Composer component

**Files:**
- Create: `frontend/src/screens/events/comments/CommentComposer.tsx`
- Create: `frontend/src/screens/events/comments/CommentComposer.test.tsx`

The composer is a textarea with a char counter and a post button. It's used both for top-level comments and for reply rows (with a `placeholder` prop and an `onSubmit` callback).

- [ ] **Step 1: Write tests**

Create `frontend/src/screens/events/comments/CommentComposer.test.tsx`:

```tsx
import { fireEvent, render, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';

import { CommentComposer } from './CommentComposer';

describe('CommentComposer', () => {
  it('disables submit when empty', () => {
    render(<CommentComposer onSubmit={vi.fn()} submitting={false} />);
    expect(screen.getByRole('button', { name: /post/i })).toBeDisabled();
  });

  it('enables submit when non-empty', () => {
    render(<CommentComposer onSubmit={vi.fn()} submitting={false} />);
    fireEvent.change(screen.getByRole('textbox'), { target: { value: 'hi' } });
    expect(screen.getByRole('button', { name: /post/i })).toBeEnabled();
  });

  it('disables submit when over the limit', () => {
    render(<CommentComposer onSubmit={vi.fn()} submitting={false} />);
    fireEvent.change(screen.getByRole('textbox'), { target: { value: 'x'.repeat(501) } });
    expect(screen.getByRole('button', { name: /post/i })).toBeDisabled();
  });

  it('submits on cmd+enter', () => {
    const onSubmit = vi.fn();
    render(<CommentComposer onSubmit={onSubmit} submitting={false} />);
    const textbox = screen.getByRole('textbox');
    fireEvent.change(textbox, { target: { value: 'hi' } });
    fireEvent.keyDown(textbox, { key: 'Enter', metaKey: true });
    expect(onSubmit).toHaveBeenCalledWith('hi');
  });

  it('shows counter warning color near limit', () => {
    render(<CommentComposer onSubmit={vi.fn()} submitting={false} />);
    fireEvent.change(screen.getByRole('textbox'), { target: { value: 'x'.repeat(460) } });
    expect(screen.getByTestId('comment-char-counter')).toHaveAttribute(
      'data-state',
      'warning',
    );
  });
});
```

- [ ] **Step 2: Run the test — confirm failure**

```bash
cd frontend && pnpm exec vitest run src/screens/events/comments/CommentComposer.test.tsx
```

Expected: import failure.

- [ ] **Step 3: Implement the composer**

Create `frontend/src/screens/events/comments/CommentComposer.tsx`:

```tsx
import { useState } from 'react';

import { Button } from '@/components/ui/Button';
import { Textarea } from '@/components/ui/Textarea';

const MAX = 500;
const WARN = 450;

interface Props {
  onSubmit: (body: string) => void;
  submitting: boolean;
  placeholder?: string;
  autoFocus?: boolean;
}

function counterState(length: number): 'ok' | 'warning' | 'over' {
  if (length >= MAX) return 'over';
  if (length >= WARN) return 'warning';
  return 'ok';
}

function counterClass(state: ReturnType<typeof counterState>): string {
  if (state === 'over') return 'text-red-500';
  if (state === 'warning') return 'text-amber-500';
  return 'text-foreground-tertiary';
}

export function CommentComposer({
  onSubmit,
  submitting,
  placeholder = 'say something…',
  autoFocus = false,
}: Props) {
  const [value, setValue] = useState('');
  const trimmed = value.trim();
  const state = counterState(value.length);
  const disabled = submitting || trimmed.length === 0 || state === 'over';

  const submit = () => {
    if (disabled) return;
    onSubmit(trimmed);
    setValue('');
  };

  return (
    <div className="flex flex-col gap-2">
      <Textarea
        value={value}
        onChange={(e) => setValue(e.target.value)}
        placeholder={placeholder}
        autoFocus={autoFocus}
        rows={3}
        aria-label="comment"
        onKeyDown={(e) => {
          if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) {
            e.preventDefault();
            submit();
          }
        }}
      />
      <div className="flex items-center justify-between">
        <span
          data-testid="comment-char-counter"
          data-state={state}
          className={`text-xs ${counterClass(state)}`}
        >
          {value.length}/{MAX}
        </span>
        <Button onClick={submit} disabled={disabled} size="sm">
          post
        </Button>
      </div>
    </div>
  );
}
```

If `Button` doesn't accept a `size` prop, drop it. If `Textarea` is a different component name, swap to the actual primitive path.

- [ ] **Step 4: Run tests + typecheck + lint**

```bash
cd frontend && pnpm exec vitest run src/screens/events/comments/CommentComposer.test.tsx
make agent-frontend-typecheck
make agent-frontend-lint
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add frontend/src/screens/events/comments/CommentComposer.tsx frontend/src/screens/events/comments/CommentComposer.test.tsx
git commit -m "$(cat <<'EOF'
feat(comments): CommentComposer component

Textarea + char counter + post button. Cmd/Ctrl+Enter submits.
Disabled while empty, over 500 chars, or submitting. Counter color
warns at 450 chars.
EOF
)"
```

---

## Task 16: ReactionBar and DeleteCommentDialog components

**Files:**
- Create: `frontend/src/screens/events/comments/ReactionBar.tsx`
- Create: `frontend/src/screens/events/comments/ReactionBar.test.tsx`
- Create: `frontend/src/screens/events/comments/DeleteCommentDialog.tsx`

### ReactionBar

- [ ] **Step 1: Write tests**

Create `frontend/src/screens/events/comments/ReactionBar.test.tsx`:

```tsx
import { fireEvent, render, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';

import type { CommentReactionSummary } from '@/models/eventComment';
import { ReactionEmoji } from '@/models/eventComment';

import { ReactionBar } from './ReactionBar';

const summary = (emoji: string, count: number, mine = false): CommentReactionSummary => ({
  emoji: emoji as CommentReactionSummary['emoji'],
  count,
  reactedByMe: mine,
});

describe('ReactionBar', () => {
  it('renders all 6 emojis and shows counts > 0', () => {
    render(
      <ReactionBar
        reactions={[summary(ReactionEmoji.Heart, 3, true)]}
        canReact
        onToggle={vi.fn()}
      />,
    );
    const heart = screen.getByRole('button', { name: /❤️/u });
    expect(heart).toHaveAttribute('aria-pressed', 'true');
    expect(heart).toHaveTextContent('3');
  });

  it('omits count when zero', () => {
    render(<ReactionBar reactions={[]} canReact onToggle={vi.fn()} />);
    const fire = screen.getByRole('button', { name: /🔥/u });
    expect(fire).not.toHaveTextContent('0');
  });

  it('disables all buttons when canReact is false', () => {
    render(<ReactionBar reactions={[]} canReact={false} onToggle={vi.fn()} />);
    for (const btn of screen.getAllByRole('button')) {
      expect(btn).toBeDisabled();
    }
  });

  it('calls onToggle with the emoji', () => {
    const onToggle = vi.fn();
    render(<ReactionBar reactions={[]} canReact onToggle={onToggle} />);
    fireEvent.click(screen.getByRole('button', { name: /🌱/u }));
    expect(onToggle).toHaveBeenCalledWith(ReactionEmoji.Seedling);
  });
});
```

- [ ] **Step 2: Implement ReactionBar**

Create `frontend/src/screens/events/comments/ReactionBar.tsx`:

```tsx
import type { CommentReactionSummary, ReactionEmojiValue } from '@/models/eventComment';
import { REACTION_EMOJI_ORDER } from '@/models/eventComment';

interface Props {
  reactions: CommentReactionSummary[];
  canReact: boolean;
  onToggle: (emoji: ReactionEmojiValue) => void;
  disabledReason?: string;
}

export function ReactionBar({ reactions, canReact, onToggle, disabledReason }: Props) {
  const byEmoji = new Map(reactions.map((r) => [r.emoji, r]));
  return (
    <div className="flex flex-wrap gap-1" role="group" aria-label="reactions">
      {REACTION_EMOJI_ORDER.map((emoji) => {
        const summary = byEmoji.get(emoji);
        const count = summary?.count ?? 0;
        const pressed = summary?.reactedByMe ?? false;
        return (
          <button
            key={emoji}
            type="button"
            aria-pressed={pressed}
            disabled={!canReact}
            title={!canReact ? disabledReason : undefined}
            onClick={() => onToggle(emoji)}
            className={[
              'inline-flex items-center gap-1 rounded-full border px-2 py-0.5 text-sm transition',
              pressed
                ? 'bg-accent-soft border-accent text-accent-foreground'
                : 'border-border bg-surface text-foreground hover:bg-surface-hover',
              !canReact ? 'opacity-50 cursor-not-allowed' : '',
            ].join(' ')}
          >
            <span>{emoji}</span>
            {count > 0 ? <span className="text-xs">{count}</span> : null}
          </button>
        );
      })}
    </div>
  );
}
```

If the project's button styles use specific design-system classes, swap in the existing ones (look for tag-pill or chip styling in `frontend/src/components/`).

- [ ] **Step 3: Run tests + typecheck**

```bash
cd frontend && pnpm exec vitest run src/screens/events/comments/ReactionBar.test.tsx
make agent-frontend-typecheck
```

### DeleteCommentDialog

- [ ] **Step 4: Implement the dialog (no test, it's a thin wrapper)**

Create `frontend/src/screens/events/comments/DeleteCommentDialog.tsx`:

```tsx
import { ConfirmDialog } from '@/components/ui/ConfirmDialog';

interface Props {
  open: boolean;
  onClose: () => void;
  onConfirm: () => void;
  submitting: boolean;
}

export function DeleteCommentDialog({ open, onClose, onConfirm, submitting }: Props) {
  return (
    <ConfirmDialog
      open={open}
      onClose={onClose}
      title="delete comment?"
      body="this can't be undone. replies will stay visible."
      confirmLabel={submitting ? 'deleting…' : 'delete'}
      confirmTone="destructive"
      onConfirm={onConfirm}
    />
  );
}
```

If `ConfirmDialog`'s prop names differ (e.g. it uses `description` instead of `body`), adjust to match the actual component. Run typecheck after to catch mismatches.

- [ ] **Step 5: Typecheck + lint + commit**

```bash
make agent-frontend-typecheck
make agent-frontend-lint
git add frontend/src/screens/events/comments/ReactionBar.tsx frontend/src/screens/events/comments/ReactionBar.test.tsx frontend/src/screens/events/comments/DeleteCommentDialog.tsx
git commit -m "$(cat <<'EOF'
feat(comments): ReactionBar and DeleteCommentDialog

ReactionBar: six-emoji toggle row with aria-pressed and per-emoji
counts (counts hidden at zero). Disabled state when canReact is
false, with a tooltip via title.

DeleteCommentDialog: thin wrapper around the shared ConfirmDialog
with destructive tone.
EOF
)"
```

---

## Task 17: CommentItem, ReplyItem, CommentThread, EventCommentsCard

**Files:**
- Create: `frontend/src/screens/events/comments/CommentItem.tsx`
- Create: `frontend/src/screens/events/comments/CommentItem.test.tsx`
- Create: `frontend/src/screens/events/comments/ReplyItem.tsx`
- Create: `frontend/src/screens/events/comments/CommentThread.tsx`
- Create: `frontend/src/screens/events/comments/EventCommentsCard.tsx`
- Create: `frontend/src/screens/events/comments/EventCommentsCard.test.tsx`
- Create: `frontend/src/screens/events/comments/utils.ts`

This is the largest task because four components are tightly coupled. They share `utils.ts` and `ReactionBar`.

- [ ] **Step 1: Implement utils.ts**

Create `frontend/src/screens/events/comments/utils.ts`:

```ts
import { formatDistanceToNow } from 'date-fns';

export function formatRelative(iso: string): string {
  return formatDistanceToNow(new Date(iso), { addSuffix: true }).toLowerCase();
}
```

- [ ] **Step 2: Implement ReplyItem**

Create `frontend/src/screens/events/comments/ReplyItem.tsx`:

```tsx
import { useState } from 'react';

import { useDeleteComment, useToggleReaction } from '@/api/eventComments';
import type { EventCommentReply, ReactionEmojiValue } from '@/models/eventComment';

import { DeleteCommentDialog } from './DeleteCommentDialog';
import { ReactionBar } from './ReactionBar';
import { formatRelative } from './utils';

interface Props {
  reply: EventCommentReply;
  eventId: string;
  canReact: boolean;
  reactDisabledReason?: string;
}

export function ReplyItem({ reply, eventId, canReact, reactDisabledReason }: Props) {
  const toggleReaction = useToggleReaction(eventId);
  const deleteComment = useDeleteComment(eventId);
  const [confirmOpen, setConfirmOpen] = useState(false);

  const handleToggle = (emoji: ReactionEmojiValue) => {
    toggleReaction.mutate({ commentId: reply.id, emoji });
  };

  const handleDelete = () => {
    deleteComment.mutate({ commentId: reply.id }, { onSuccess: () => setConfirmOpen(false) });
  };

  return (
    <div className="border-border ml-6 border-l-2 pl-3">
      <div className="flex items-center gap-2">
        {reply.authorPhotoUrl ? (
          <img
            src={reply.authorPhotoUrl}
            alt=""
            className="h-6 w-6 rounded-full object-cover"
          />
        ) : null}
        <span className="text-sm font-medium">{reply.authorDisplayName.toLowerCase()}</span>
        <span className="text-foreground-tertiary text-xs">{formatRelative(reply.createdAt)}</span>
      </div>
      {reply.isDeleted ? (
        <p className="text-foreground-tertiary text-sm italic">[deleted]</p>
      ) : (
        <p className="text-sm whitespace-pre-wrap">{reply.body}</p>
      )}
      {!reply.isDeleted ? (
        <div className="mt-1 flex items-center justify-between gap-2">
          <ReactionBar
            reactions={reply.reactions}
            canReact={canReact}
            onToggle={handleToggle}
            disabledReason={reactDisabledReason}
          />
          {reply.canDelete ? (
            <button
              type="button"
              onClick={() => setConfirmOpen(true)}
              className="text-foreground-tertiary text-xs hover:underline"
            >
              delete
            </button>
          ) : null}
        </div>
      ) : null}
      <DeleteCommentDialog
        open={confirmOpen}
        onClose={() => setConfirmOpen(false)}
        onConfirm={handleDelete}
        submitting={deleteComment.isPending}
      />
    </div>
  );
}
```

- [ ] **Step 3: Write tests for CommentItem**

Create `frontend/src/screens/events/comments/CommentItem.test.tsx`:

```tsx
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';

import type { EventComment } from '@/models/eventComment';

import { CommentItem } from './CommentItem';

function wrap(ui: React.ReactNode) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(<QueryClientProvider client={qc}>{ui}</QueryClientProvider>);
}

const baseComment: EventComment = {
  id: 'c1',
  authorId: 'u1',
  authorDisplayName: 'Alice',
  authorPhotoUrl: '',
  body: 'hello',
  isDeleted: false,
  createdAt: '2026-01-01T00:00:00Z',
  reactions: [],
  canDelete: false,
  replies: [],
};

describe('CommentItem', () => {
  it('renders the body and author', () => {
    wrap(
      <CommentItem
        comment={baseComment}
        eventId="evt"
        canReact
        canReply
      />,
    );
    expect(screen.getByText('hello')).toBeInTheDocument();
    expect(screen.getByText('alice')).toBeInTheDocument();
  });

  it('renders [deleted] placeholder when isDeleted', () => {
    wrap(
      <CommentItem
        comment={{ ...baseComment, isDeleted: true, body: '' }}
        eventId="evt"
        canReact
        canReply
      />,
    );
    expect(screen.getByText('[deleted]')).toBeInTheDocument();
    expect(screen.queryByRole('group', { name: 'reactions' })).not.toBeInTheDocument();
  });

  it('shows delete only when canDelete is true', () => {
    wrap(
      <CommentItem
        comment={{ ...baseComment, canDelete: false }}
        eventId="evt"
        canReact
        canReply
      />,
    );
    expect(screen.queryByRole('button', { name: /delete/i })).not.toBeInTheDocument();
  });
});
```

- [ ] **Step 4: Implement CommentItem**

Create `frontend/src/screens/events/comments/CommentItem.tsx`:

```tsx
import { useState } from 'react';

import { useDeleteComment, usePostReply, useToggleReaction } from '@/api/eventComments';
import type { EventComment, ReactionEmojiValue } from '@/models/eventComment';

import { CommentComposer } from './CommentComposer';
import { DeleteCommentDialog } from './DeleteCommentDialog';
import { ReactionBar } from './ReactionBar';
import { ReplyItem } from './ReplyItem';
import { formatRelative } from './utils';

interface Props {
  comment: EventComment;
  eventId: string;
  canReact: boolean;
  canReply: boolean;
  reactDisabledReason?: string;
}

export function CommentItem({
  comment,
  eventId,
  canReact,
  canReply,
  reactDisabledReason,
}: Props) {
  const toggleReaction = useToggleReaction(eventId);
  const deleteComment = useDeleteComment(eventId);
  const postReply = usePostReply(eventId);
  const [replyOpen, setReplyOpen] = useState(false);
  const [confirmOpen, setConfirmOpen] = useState(false);

  const handleToggle = (emoji: ReactionEmojiValue) => {
    toggleReaction.mutate({ commentId: comment.id, emoji });
  };

  const handleDelete = () => {
    deleteComment.mutate({ commentId: comment.id }, { onSuccess: () => setConfirmOpen(false) });
  };

  const handleSubmitReply = (body: string) => {
    postReply.mutate(
      { parentId: comment.id, body },
      { onSuccess: () => setReplyOpen(false) },
    );
  };

  return (
    <article className="flex flex-col gap-2">
      <div className="flex items-center gap-2">
        {comment.authorPhotoUrl ? (
          <img
            src={comment.authorPhotoUrl}
            alt=""
            className="h-8 w-8 rounded-full object-cover"
          />
        ) : null}
        <span className="text-sm font-medium">
          {comment.authorDisplayName.toLowerCase()}
        </span>
        <span className="text-foreground-tertiary text-xs">
          {formatRelative(comment.createdAt)}
        </span>
      </div>
      {comment.isDeleted ? (
        <p className="text-foreground-tertiary text-sm italic">[deleted]</p>
      ) : (
        <p className="text-sm whitespace-pre-wrap">{comment.body}</p>
      )}
      {!comment.isDeleted ? (
        <div className="flex items-center justify-between gap-2">
          <ReactionBar
            reactions={comment.reactions}
            canReact={canReact}
            onToggle={handleToggle}
            disabledReason={reactDisabledReason}
          />
          <div className="flex items-center gap-3">
            {canReply ? (
              <button
                type="button"
                onClick={() => setReplyOpen((v) => !v)}
                className="text-foreground-tertiary text-xs hover:underline"
              >
                {replyOpen ? 'cancel' : 'reply'}
              </button>
            ) : null}
            {comment.canDelete ? (
              <button
                type="button"
                onClick={() => setConfirmOpen(true)}
                className="text-foreground-tertiary text-xs hover:underline"
              >
                delete
              </button>
            ) : null}
          </div>
        </div>
      ) : null}
      {replyOpen ? (
        <div className="ml-6">
          <CommentComposer
            onSubmit={handleSubmitReply}
            submitting={postReply.isPending}
            placeholder="reply…"
            autoFocus
          />
        </div>
      ) : null}
      {comment.replies.length > 0 ? (
        <div className="flex flex-col gap-2">
          {comment.replies.map((reply) => (
            <ReplyItem
              key={reply.id}
              reply={reply}
              eventId={eventId}
              canReact={canReact}
              reactDisabledReason={reactDisabledReason}
            />
          ))}
        </div>
      ) : null}
      <DeleteCommentDialog
        open={confirmOpen}
        onClose={() => setConfirmOpen(false)}
        onConfirm={handleDelete}
        submitting={deleteComment.isPending}
      />
    </article>
  );
}
```

- [ ] **Step 5: Implement CommentThread**

Create `frontend/src/screens/events/comments/CommentThread.tsx`:

```tsx
import type { EventComment } from '@/models/eventComment';

import { CommentItem } from './CommentItem';

interface Props {
  comments: EventComment[];
  eventId: string;
  canReact: boolean;
  canReply: boolean;
  reactDisabledReason?: string;
}

export function CommentThread({
  comments,
  eventId,
  canReact,
  canReply,
  reactDisabledReason,
}: Props) {
  if (comments.length === 0) {
    return (
      <p className="text-foreground-tertiary text-sm">no comments yet.</p>
    );
  }
  return (
    <div className="flex flex-col gap-6">
      {comments.map((c) => (
        <CommentItem
          key={c.id}
          comment={c}
          eventId={eventId}
          canReact={canReact}
          canReply={canReply}
          reactDisabledReason={reactDisabledReason}
        />
      ))}
    </div>
  );
}
```

- [ ] **Step 6: Write the EventCommentsCard test**

Create `frontend/src/screens/events/comments/EventCommentsCard.test.tsx`:

```tsx
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render, screen, waitFor } from '@testing-library/react';
import { http, HttpResponse } from 'msw';
import { setupServer } from 'msw/node';
import { afterAll, afterEach, beforeAll, describe, expect, it, vi } from 'vitest';

import { EventCommentsCard } from './EventCommentsCard';

vi.mock('@/auth/store', () => ({
  useAuthStore: (selector: (s: { status: string; user: unknown }) => unknown) =>
    selector({ status: 'authed', user: { id: 'u1' } }),
}));

const eventId = '11111111-1111-1111-1111-111111111111';
const server = setupServer();

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

function renderCard() {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={qc}>
      <EventCommentsCard eventId={eventId} />
    </QueryClientProvider>,
  );
}

describe('EventCommentsCard', () => {
  it('shows the composer when the viewer can post', async () => {
    server.use(
      http.get(`*/api/community/events/${eventId}/comments/`, () =>
        HttpResponse.json({ items: [], can_post: true, cannot_post_reason: null }),
      ),
    );
    renderCard();
    await waitFor(() =>
      expect(screen.getByRole('button', { name: /post/i })).toBeInTheDocument(),
    );
  });

  it('shows the rsvp prompt when the viewer is logged in but not RSVPd', async () => {
    server.use(
      http.get(`*/api/community/events/${eventId}/comments/`, () =>
        HttpResponse.json({
          items: [],
          can_post: false,
          cannot_post_reason: 'rsvp_required',
        }),
      ),
    );
    renderCard();
    await waitFor(() =>
      expect(screen.getByText(/rsvp to join the conversation/i)).toBeInTheDocument(),
    );
    expect(screen.queryByRole('button', { name: /post/i })).not.toBeInTheDocument();
  });
});
```

If `msw` is not the convention this repo uses (check `eventPolls.ts` tests), substitute `vi.mock('@/api/eventComments', ...)` to return canned values for `useEventComments`.

- [ ] **Step 7: Implement EventCommentsCard**

Create `frontend/src/screens/events/comments/EventCommentsCard.tsx`:

```tsx
import { useEventComments, usePostComment } from '@/api/eventComments';

import { CommentComposer } from './CommentComposer';
import { CommentThread } from './CommentThread';

interface Props {
  eventId: string;
}

export function EventCommentsCard({ eventId }: Props) {
  const { data, isPending, isError } = useEventComments(eventId);
  const postComment = usePostComment(eventId);

  if (isPending) {
    return (
      <section className="border-border bg-surface rounded-lg border p-4">
        <h2 className="text-muted mb-3 text-xs font-medium tracking-wide">comments</h2>
        <p className="text-foreground-tertiary text-sm">loading…</p>
      </section>
    );
  }
  if (isError || !data) {
    return (
      <section className="border-border bg-surface rounded-lg border p-4">
        <h2 className="text-muted mb-3 text-xs font-medium tracking-wide">comments</h2>
        <p className="text-foreground-tertiary text-sm">
          couldn't load comments — try refreshing.
        </p>
      </section>
    );
  }

  const canReact = data.canPost; // same gate as posting
  const reactDisabledReason =
    data.cannotPostReason === 'login_required'
      ? 'log in to react'
      : data.cannotPostReason === 'rsvp_required'
        ? 'rsvp to react'
        : undefined;

  return (
    <section className="border-border bg-surface rounded-lg border p-4">
      <h2 className="text-muted mb-3 text-xs font-medium tracking-wide">comments</h2>
      {data.canPost ? (
        <div className="mb-4">
          <CommentComposer
            onSubmit={(body) => postComment.mutate({ body })}
            submitting={postComment.isPending}
          />
        </div>
      ) : data.cannotPostReason === 'rsvp_required' ? (
        <p className="text-foreground-tertiary mb-4 text-sm">rsvp to join the conversation.</p>
      ) : (
        <p className="text-foreground-tertiary mb-4 text-sm">log in to comment.</p>
      )}
      <CommentThread
        comments={data.items}
        eventId={eventId}
        canReact={canReact}
        canReply={data.canPost}
        reactDisabledReason={reactDisabledReason}
      />
    </section>
  );
}
```

- [ ] **Step 8: Run all comment-component tests**

```bash
cd frontend && pnpm exec vitest run src/screens/events/comments/
```

Expected: all pass.

- [ ] **Step 9: Typecheck + lint + commit**

```bash
make agent-frontend-typecheck
make agent-frontend-lint
git add frontend/src/screens/events/comments/
git commit -m "$(cat <<'EOF'
feat(comments): comment thread components

EventCommentsCard owns the data fetch + composer state.
CommentThread renders the list.
CommentItem handles top-level comments + the reply composer + delete.
ReplyItem mirrors CommentItem for replies (no nested replies).
Soft-delete shows [deleted] placeholder; reactions hidden on deleted rows.
EOF
)"
```

---

## Task 18: Integrate into EventMemberSection + manual QA

**Files:**
- Modify: `frontend/src/screens/events/EventMemberSection.tsx:67` (insert position approximate; see file)

- [ ] **Step 1: Add the import**

Edit `frontend/src/screens/events/EventMemberSection.tsx`. Near the top with other imports:

```tsx
import { EventCommentsCard } from './comments/EventCommentsCard';
```

- [ ] **Step 2: Render the card below RsvpSection**

Inside the `EventMemberSection` function's return, find the JSX block containing `<Card label="rsvp">` (around line 56–60). Immediately after the `Card`/`RsvpSection` block — and *before* `<EventAdminActions>` — add:

```tsx
<EventCommentsCard eventId={event.id} />
```

The card renders its own `<section>` wrapper, so it sits alongside the other `<Card>` blocks visually.

- [ ] **Step 3: Run the full frontend test suite**

```bash
cd frontend && pnpm exec vitest run
make agent-frontend-typecheck
make agent-frontend-lint
```

Expected: all pass. If `EventMemberSection.test.tsx` snapshots break because of the new child, update the snapshot.

- [ ] **Step 4: Manual smoke test**

Run:
```bash
cd /Users/leahpeker/development/pda-worktrees/spec-event-comments-reactions
make db-start
make migrate
make seed
make dev
```

In a browser at `http://localhost:5173` (or whatever port Vite picks):

For each role, verify the expected behavior. (Use the seeded users or create new ones as needed.)

1. **Logged-out viewer on a public event**: comments section is visible; no composer; says "log in to comment"; reactions are disabled with a tooltip.
2. **Logged-in viewer, no RSVP**: comments section is visible; "rsvp to join the conversation"; reactions disabled with "rsvp to react".
3. **Logged-in, RSVP'd**: composer renders; can post a comment; can reply; can react/un-react; reaction count updates instantly (optimistic); can delete own comment.
4. **Event creator**: can delete other people's comments; the reply button works.
5. **`ManageEvents` admin**: can delete other people's comments.
6. **Soft-delete behavior**: after deleting a comment with replies, the comment shows `[deleted]` but the replies remain visible.
7. **Reply depth**: there is no reply button on reply rows (only top-level comments).
8. **Char limit**: typing past 500 disables the post button; counter turns warning color around 450.
9. **`invite_only` event** (if a seeded one exists): a non-invitee gets the section hidden or an error message; an invitee sees normally.

Watch the browser console for errors. Watch the network panel for 4xx responses on operations that should succeed.

- [ ] **Step 5: Final CI run**

```bash
cd /Users/leahpeker/development/pda-worktrees/spec-event-comments-reactions
make agent-ci
```

Expected: clean pass.

- [ ] **Step 6: Commit and push**

```bash
git add frontend/src/screens/events/EventMemberSection.tsx
git commit -m "$(cat <<'EOF'
feat(comments): mount EventCommentsCard in EventMemberSection

Renders below RsvpSection and above EventAdminActions. The card is
only visible to authed users (EventMemberSection itself is auth-gated
in EventDetailScreen); the API does not require auth to read, so
this is consistent with the design's "logged-in to see" stance.
EOF
)"
git push origin spec/event-comments-reactions
```

- [ ] **Step 7: Mark PR 1 ready for review**

Open https://github.com/ProteinDeficientsAnonymous/pda/pull/426 and click "ready for review" (or use `gh pr ready 426`). Update the PR description: replace the spec-only summary with a real summary of what shipped, leaving the spec link intact. **Do not merge.** That requires explicit user approval.

---

# PR 2 — Reply notifications

This PR depends on PR 1 being merged (or layered on top of the same branch). It's a small, additive change.

## Task 19: Branch off latest main

- [ ] **Step 1: Fetch and create the branch**

After PR 1 has merged:

```bash
cd /Users/leahpeker/development/pda
git fetch origin main
git worktree add -b feat/comment-reply-notifications /Users/leahpeker/development/pda-worktrees/comment-reply-notifications origin/main
cd /Users/leahpeker/development/pda-worktrees/comment-reply-notifications
make agent-ci
```

Expected: clean baseline. PR 1's code is now on main.

If PR 1 has not merged yet but you want to start PR 2 against PR 1's branch, swap `origin/main` for `origin/spec/event-comments-reactions` above. The PR description should make the dependency explicit.

---

## Task 20: Add `COMMENT_REPLY` to NotificationType + migration

**Files:**
- Modify: `backend/notifications/models.py:10-21` (add enum value)
- Create: `backend/notifications/migrations/00XX_comment_reply.py` (generated)

- [ ] **Step 1: Add the enum value**

Edit `backend/notifications/models.py`. In `class NotificationType(models.TextChoices)`, append:

```python
    COMMENT_REPLY = "comment_reply", "Comment Reply"
```

The key `"comment_reply"` is 13 chars, well within `max_length=32`.

- [ ] **Step 2: Generate the migration**

```bash
make migrate
```

This creates a migration in `backend/notifications/migrations/` that alters the `notification_type` field's choices. The on-disk values are unchanged for existing rows.

- [ ] **Step 3: Verify**

```bash
cd backend && uv run python manage.py showmigrations notifications | tail -3
```

Expected: the new migration is `[X]` applied.

- [ ] **Step 4: Commit**

```bash
cd /Users/leahpeker/development/pda-worktrees/comment-reply-notifications
git add backend/notifications/models.py backend/notifications/migrations/
git commit -m "$(cat <<'EOF'
feat(notifications): add COMMENT_REPLY notification type

Enum-widening migration. Existing rows unaffected; no backfill.
Reversible.
EOF
)"
```

---

## Task 21: Add `notify_comment_reply` helper

**Files:**
- Modify: `backend/notifications/service.py:235+` (add new helper near existing ones)
- Modify: `backend/tests/test_in_app_notifications.py` (or `test_notifications.py` — whichever covers service helpers)

- [ ] **Step 1: Write the failing test**

Append to `backend/tests/test_in_app_notifications.py` (or `test_notifications.py` — whichever houses notification-service tests):

```python
import pytest

from community.models import Event, EventComment, EventRSVP, RSVPStatus
from notifications.models import Notification, NotificationType
from notifications.service import notify_comment_reply
from tests.conftest import future_iso


@pytest.mark.django_db
class TestNotifyCommentReply:
    def test_notifies_parent_author(self, test_user, db):
        from users.models import User

        replier = User.objects.create_user(
            phone_number="+12025550707",
            password="replierpass",
            display_name="Replier",
        )
        event = Event.objects.create(
            title="E",
            start_datetime=future_iso(days=10),
            created_by=test_user,
        )
        parent = EventComment.objects.create(event=event, author=test_user, body="parent")
        reply = EventComment.objects.create(
            event=event, author=replier, body="reply", parent=parent
        )
        notify_comment_reply(reply)
        notifs = Notification.objects.filter(
            recipient=test_user, notification_type=NotificationType.COMMENT_REPLY
        )
        assert notifs.count() == 1
        n = notifs.first()
        assert n.event_id == event.id
        assert n.related_user_id == replier.id
        assert "replier" in n.message.lower() or "Replier" in n.message

    def test_no_self_notify(self, test_user, db):
        event = Event.objects.create(
            title="E",
            start_datetime=future_iso(days=10),
            created_by=test_user,
        )
        parent = EventComment.objects.create(event=event, author=test_user, body="p")
        reply = EventComment.objects.create(
            event=event, author=test_user, body="r", parent=parent
        )
        notify_comment_reply(reply)
        assert Notification.objects.filter(
            recipient=test_user, notification_type=NotificationType.COMMENT_REPLY
        ).count() == 0

    def test_noop_for_top_level(self, test_user, db):
        event = Event.objects.create(
            title="E",
            start_datetime=future_iso(days=10),
            created_by=test_user,
        )
        comment = EventComment.objects.create(event=event, author=test_user, body="top")
        notify_comment_reply(comment)
        assert Notification.objects.filter(
            notification_type=NotificationType.COMMENT_REPLY
        ).count() == 0
```

- [ ] **Step 2: Run the test — confirm failure**

```bash
cd backend && uv run pytest tests/test_in_app_notifications.py -k notify_comment_reply -q
```

Expected: ImportError on `notify_comment_reply`.

- [ ] **Step 3: Implement the helper**

Append to `backend/notifications/service.py`:

```python
def notify_comment_reply(reply) -> None:
    """Notify the parent comment's author that someone replied to them.

    No-op if `reply` is a top-level comment or if the replier is the
    parent's author.
    """
    from notifications.models import Notification, NotificationType

    if reply.parent_id is None:
        return
    parent_author_id = reply.parent.author_id
    if str(parent_author_id) == str(reply.author_id):
        return
    replier_name = reply.author.display_name or reply.author.phone_number
    event_title = reply.event.title
    Notification.objects.create(
        recipient_id=parent_author_id,
        notification_type=NotificationType.COMMENT_REPLY,
        event=reply.event,
        related_user=reply.author,
        message=f"{replier_name} replied to your comment on {event_title}",
    )
    _notify_users([str(parent_author_id)])
```

- [ ] **Step 4: Run the tests**

```bash
cd backend && uv run pytest tests/test_in_app_notifications.py -k notify_comment_reply -q
```

Expected: all three pass.

- [ ] **Step 5: Lint + typecheck + commit**

```bash
make agent-lint
make agent-typecheck
git add backend/notifications/service.py backend/tests/test_in_app_notifications.py
git commit -m "$(cat <<'EOF'
feat(notifications): notify_comment_reply helper

Creates a COMMENT_REPLY notification for the parent comment's author
when someone else replies, then fires pg_notify so the SSE bell
updates. No-op for top-level comments and self-replies.
EOF
)"
```

---

## Task 22: Wire the helper into the reply endpoint

**Files:**
- Modify: `backend/community/_event_comments.py` (reply endpoint)
- Modify: `backend/tests/test_event_comments.py`

- [ ] **Step 1: Add an integration test**

Append to `backend/tests/test_event_comments.py`:

```python
from notifications.models import Notification, NotificationType


@pytest.mark.django_db
class TestReplyNotifications:
    def test_reply_creates_notification_for_parent_author(
        self, api_client, rsvp_user, rsvp_headers, event_with_rsvp, db
    ):
        # parent authored by a different RSVPd user
        from users.models import User
        from ninja_jwt.tokens import RefreshToken

        author = User.objects.create_user(
            phone_number="+12025550808",
            password="authorpass",
            display_name="Author",
        )
        EventRSVP.objects.create(event=event_with_rsvp, user=author, status=RSVPStatus.YES)
        parent = EventComment.objects.create(
            event=event_with_rsvp, author=author, body="parent"
        )
        # rsvp_user replies
        response = api_client.post(
            f"/api/community/events/{event_with_rsvp.id}/comments/{parent.id}/replies/",
            data=json.dumps({"body": "reply"}),
            content_type="application/json",
            **rsvp_headers,
        )
        assert response.status_code == 201
        notifs = Notification.objects.filter(
            recipient=author, notification_type=NotificationType.COMMENT_REPLY
        )
        assert notifs.count() == 1
```

- [ ] **Step 2: Run the test**

Expected: fail — endpoint doesn't call the helper yet.

- [ ] **Step 3: Wire the helper in**

Edit `backend/community/_event_comments.py`. Inside `post_reply`, replace the existing transaction block:

```python
    with transaction.atomic():
        reply = EventComment.objects.create(
            event=event, author=user, body=payload.body, parent=parent
        )
```

with:

```python
    from notifications.service import notify_comment_reply

    with transaction.atomic():
        reply = EventComment.objects.create(
            event=event, author=user, body=payload.body, parent=parent
        )
        notify_comment_reply(reply)
```

The import is deferred to avoid a top-of-module circular dependency between the community and notifications apps. (This is the same pattern other notify_* helper callers use — confirm by grep.)

- [ ] **Step 4: Run tests**

```bash
cd backend && uv run pytest tests/test_event_comments.py::TestReplyNotifications -q
```

Expected: pass.

Also re-run the full comments suite to confirm nothing else broke:

```bash
cd backend && uv run pytest tests/test_event_comments.py -q
```

- [ ] **Step 5: Lint + typecheck + commit**

```bash
make agent-lint
make agent-typecheck
git add backend/community/_event_comments.py backend/tests/test_event_comments.py
git commit -m "$(cat <<'EOF'
feat(comments): trigger reply notification on POST replies

post_reply now calls notify_comment_reply inside the same
transaction.atomic() as the comment create, so the notification is
rolled back if the comment is.
EOF
)"
```

---

## Task 23: Regenerate frontend types

**Files:**
- Modify: `frontend/src/api/types.gen.ts` (generated)
- Modify: `frontend/src/api/validationCodes.gen.ts` (generated)

- [ ] **Step 1: Regenerate**

```bash
cd /Users/leahpeker/development/pda-worktrees/comment-reply-notifications
make frontend-types
```

Expected: `NotificationType` enum in `types.gen.ts` now includes `"comment_reply"`.

- [ ] **Step 2: Commit**

```bash
git add frontend/src/api/types.gen.ts frontend/src/api/validationCodes.gen.ts
git commit -m "$(cat <<'EOF'
feat(notifications): regenerate FE types with COMMENT_REPLY
EOF
)"
```

---

## Task 24: Frontend NotificationType + rendering

**Files:**
- Modify: `frontend/src/models/notification.ts` — add `'comment_reply'` to the enum
- Modify: wherever notifications are rendered (likely `frontend/src/layout/NotificationBell.tsx` or a sibling file) — add a case for the new type

- [ ] **Step 1: Find the notification model + renderer**

```bash
cd /Users/leahpeker/development/pda-worktrees/comment-reply-notifications
grep -rn "NotificationType\|notificationType\|notification_type" frontend/src/ | head -20
```

Identify:
- The TS enum/const for notification types.
- The renderer that maps a `Notification` to display text and a destination URL.

- [ ] **Step 2: Add the value to the model**

Edit `frontend/src/models/notification.ts` (or wherever the enum lives). Add a `'comment_reply'` member matching the existing pattern (probably an `as const` object).

- [ ] **Step 3: Add the renderer case**

Wherever notifications are rendered as a list item, add a case for `'comment_reply'`. The message text already comes from the backend (`"{name} replied to your comment on {event}"`). Use `.toLowerCase()` on whatever's displayed if other notification types do. The destination link should route to the event detail page using `notification.event` / `notification.eventId`.

- [ ] **Step 4: Write a test for the renderer**

If the renderer has tests, add a case for `comment_reply`. Example structure:

```tsx
import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';

import { NotificationRow } from './NotificationRow'; // adjust to actual

describe('NotificationRow', () => {
  it('renders a comment_reply notification', () => {
    render(
      <NotificationRow
        notification={{
          id: 'n1',
          notificationType: 'comment_reply',
          message: 'Replier replied to your comment on E',
          eventId: 'evt',
          relatedUserId: 'u2',
          isRead: false,
          createdAt: '2026-01-01T00:00:00Z',
        }}
      />,
    );
    expect(screen.getByText(/replied to your comment/i)).toBeInTheDocument();
  });
});
```

Adjust prop shape to match the actual `Notification` type.

- [ ] **Step 5: Frontend test + typecheck + lint**

```bash
cd frontend && pnpm exec vitest run
make agent-frontend-typecheck
make agent-frontend-lint
```

Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add frontend/src/
git commit -m "$(cat <<'EOF'
feat(notifications): render COMMENT_REPLY notification

Adds the FE side of the new notification type so the bell + list
display the message and link to the event detail page.
EOF
)"
```

---

## Task 25: Manual end-to-end QA

- [ ] **Step 1: Start the stack**

```bash
cd /Users/leahpeker/development/pda-worktrees/comment-reply-notifications
make db-start
make migrate
make seed
make dev
```

- [ ] **Step 2: Verify the notification flow**

1. Log in as user A. Post a top-level comment on an event.
2. Log out, log in as user B (must have an RSVP on the same event).
3. Reply to user A's comment.
4. Log out, log back in as user A.
5. The notification bell should show a 1 (or unread-state badge). The new entry should say "<user b> replied to your comment on <event title>" and clicking should navigate to the event.

Also verify negatives:
- User B replies to their own comment → no notification.
- User B posts a top-level comment (not a reply) → no notification.

- [ ] **Step 3: Final CI run**

```bash
make agent-ci
```

Expected: clean pass.

---

## Task 26: Push PR 2 and mark ready

- [ ] **Step 1: Push**

```bash
cd /Users/leahpeker/development/pda-worktrees/comment-reply-notifications
git push -u origin feat/comment-reply-notifications
```

- [ ] **Step 2: Open the PR**

```bash
gh pr create --title "feat: reply notifications for event comments" --body "$(cat <<'EOF'
## Summary
- Adds `NotificationType.COMMENT_REPLY` (migration on `notifications` app).
- Adds `notify_comment_reply(reply)` helper that creates the Notification + fires the existing pg_notify channel.
- Wires the helper into the reply endpoint inside the same transaction as the comment create.
- Regenerates frontend types and adds rendering for the new notification type.

Depends on the comments + reactions PR (#426) being merged first.

## Test plan
- [ ] User A's reply to user B notifies user B
- [ ] User A replying to their own comment does NOT notify anyone
- [ ] Top-level comments do not produce notifications
- [ ] Notification bell badge updates without a page refresh (SSE)
- [ ] Clicking the notification links to the event detail page
- [ ] `make agent-ci` passes
EOF
)"
```

- [ ] **Step 3: Mark ready when QA is clean**

Do not merge. Wait for explicit user approval per project rule.

---

# Out of scope — Phase 2 (@mentions)

Will be planned separately after Phase 1 ships. The Phase 1 data model already supports it without changes: Phase 2 adds a `CommentMention(comment, user)` join table, a mention-picker in the composer, and a `COMMENT_MENTION` notification type. Mention parsing strategy and storage format (`@[uuid]` markers vs. join table only) will be decided during Phase 2 brainstorming, not now.
