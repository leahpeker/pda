# feat: flexible survey/form builder (issue #144)

## Context

Replace CryptPad feedback forms with an in-app survey system. Admins create surveys (event feedback, general feedback, or any custom survey) via the admin panel. Surveys have flexible question types. Responses are optionally tied to logged-in users. Import of old CryptPad data deferred to later.

## Data Model

### Backend Models (`backend/community/models.py`)

**`Survey`** — a named form/survey
```
id              UUIDField (pk)
title           CharField(max_length=200)
description     TextField(blank=True, default="")
slug            SlugField(unique=True)        # for URL: /surveys/<slug>
visibility      CharField(choices=SurveyVisibility)  # public / members_only
is_active       BooleanField(default=True)    # toggleable by admin
linked_event    ForeignKey(Event, null=True, blank=True, on_delete=SET_NULL)
created_by      ForeignKey(User, null=True, on_delete=SET_NULL)
created_at      DateTimeField(auto_now_add=True)
```

`SurveyVisibility(TextChoices)`: `public`, `members_only`

**`SurveyQuestion`** — mirrors `JoinFormQuestion` pattern but extended
```
id              UUIDField (pk)
survey          ForeignKey(Survey, related_name="questions", on_delete=CASCADE)
label           CharField(max_length=500)
field_type      CharField(choices=SurveyQuestionType)
options         JSONField(default=list)       # for select/multiselect/dropdown
required        BooleanField(default=False)
display_order   PositiveIntegerField(default=0)
```

`SurveyQuestionType(TextChoices)`: `text`, `textarea`, `select`, `multiselect`, `dropdown`, `number`, `yes_no`, `rating`

**`SurveyResponse`** — one per submission
```
id              UUIDField (pk)
survey          ForeignKey(Survey, related_name="responses", on_delete=CASCADE)
user            ForeignKey(User, null=True, blank=True, on_delete=SET_NULL)
answers         JSONField(default=dict)       # {question_id: {label, answer}} (same pattern as JoinRequest.custom_answers)
submitted_at    DateTimeField(auto_now_add=True)
```

### Permission

Add `manage_surveys` to `PermissionKey` in `backend/users/permissions.py`.

## API Endpoints (`backend/community/api.py`)

### Admin (auth=JWTAuth, permission=manage_surveys)
| Method | Path | Description |
|--------|------|-------------|
| GET | `/surveys/admin/` | List all surveys (with response counts) |
| POST | `/surveys/` | Create survey |
| PATCH | `/surveys/{id}/` | Update survey metadata |
| DELETE | `/surveys/{id}/` | Delete survey + cascade |
| POST | `/surveys/{id}/questions/` | Add question |
| PATCH | `/surveys/{id}/questions/{qid}/` | Update question |
| DELETE | `/surveys/{id}/questions/{qid}/` | Delete question |
| PUT | `/surveys/{id}/questions/order/` | Reorder questions |
| GET | `/surveys/{id}/responses/` | View responses (admin) |

### Public / member
| Method | Path | Description |
|--------|------|-------------|
| GET | `/surveys/{slug}/` | Get survey + questions (public or members_only based on visibility) |
| POST | `/surveys/{slug}/respond/` | Submit response (auth=_optional_jwt) |

## Frontend

### Models (`frontend/lib/models/`)

**`survey.dart`** — Freezed: `Survey`, `SurveyQuestion`, `SurveyResponse`

### Providers (`frontend/lib/providers/`)

**`survey_provider.dart`** — `FutureProvider.family<Survey, String>` keyed by slug (public fetch)
**`survey_admin_provider.dart`** — `AsyncNotifier<List<Survey>>` with full CRUD (mirrors `join_form_admin_provider.dart` pattern)
**`survey_responses_provider.dart`** — `FutureProvider.family<List<SurveyResponse>, String>` keyed by survey id

### Screens (`frontend/lib/screens/`)

**`survey_admin_screen.dart`** — List of surveys in the admin panel (create/edit/delete/toggle active). Accessible from admin hub.
**`survey_builder_screen.dart`** — Edit a single survey: metadata + `ReorderableListView` of questions with add/edit/delete dialogs (mirrors `join_form_config_screen.dart`).
**`survey_responses_screen.dart`** — View responses for a survey (table/list view).
**`survey_screen.dart`** — Public-facing survey form. Renders questions dynamically by `field_type`. Submit button posts response.

### Routes (`frontend/lib/router/app_router.dart`)

| Path | Auth | Screen |
|------|------|--------|
| `/admin/surveys` | Yes + manage_surveys | SurveyAdminScreen |
| `/admin/surveys/:id` | Yes + manage_surveys | SurveyBuilderScreen |
| `/admin/surveys/:id/responses` | Yes + manage_surveys | SurveyResponsesScreen |
| `/surveys/:slug` | Depends on visibility | SurveyScreen |

### Admin hub card

Add a "surveys" card to `admin_screen.dart` gated on `manage_surveys`.

### Nav

Add a "feedback" or "surveys" link to the public nav (or link from event detail when `linked_event` is set).

## Implementation Order

This is a large feature — break into phases:

### Phase 1: Backend models + migrations + admin API
- Models: `Survey`, `SurveyQuestion`, `SurveyResponse`
- Permission: `manage_surveys`
- Admin CRUD endpoints + schemas
- Backend tests

### Phase 2: Frontend admin — survey list + builder
- Freezed models
- Admin provider (CRUD)
- Survey admin screen (list)
- Survey builder screen (questions)
- Routes, admin hub card, permission label

### Phase 3: Public survey form + responses
- Public survey fetch provider
- Survey screen (dynamic form rendering)
- Submit response endpoint + frontend
- Responses admin view

### Phase 4: Polish
- Link surveys to events (show feedback link on event detail)
- Response export (CSV)
- Survey analytics/summary view

## Verification

Each phase: `make ci` (backend + frontend lint/test/typecheck)

## Existing code to reuse
- `JoinFormQuestion` model pattern → `SurveyQuestion`
- `JoinFormConfigScreen` → `SurveyBuilderScreen` (reorder, dialogs)
- `join_form_admin_provider.dart` → `survey_admin_provider.dart`
- `_validate_answers()` pattern from join form → survey response validation
- `PermissionKey` + `kPermissionLabels` pattern for new permission
- `add-perm-and-page` skill checklist for the permission wiring
