# feat: official vs community events

## Context

Events are currently all treated the same — any logged-in member can create one. We need to distinguish "official" PDA events from community-submitted events because:
- Only official events should be linkable to feedback surveys
- Official events should only be creatable by users with `manage_events` permission
- Community events remain open for any member to create

## Data Model

### Backend (`backend/community/models.py`)

Add `EventType(TextChoices)`:
- `official` — PDA-organized events, created by admins
- `community` — member-submitted events

Add field to `Event`:
```python
event_type = CharField(max_length=20, choices=EventType.choices, default=EventType.COMMUNITY)
```

Migration needed.

### Backend API changes (`backend/community/api.py`)

**Create event**: Add `event_type` to `EventIn` (default `"community"`). If `event_type == "official"`, check `has_permission(MANAGE_EVENTS)` — return 403 if not. Community events remain open to any authenticated user.

**Update event**: Add `event_type` to `EventPatchIn`. Same permission check if changing to official.

**Schemas**: Add `event_type` to `EventOut` and `EventListOut`.

**Survey linking**: Existing `linked_event` FK on `Survey` already works — just validate in the survey creation endpoint that the linked event is official.

### Frontend

**Event model** (`frontend/lib/models/event.dart`): Add `@Default('community') String eventType` to the Freezed class + codegen.

**Event form dialog** (`frontend/lib/screens/calendar/event_form_dialog.dart`): Show an "official event" toggle only when the user has `manage_events` permission. Default to `community`. When official is selected, the event type is sent in the POST/PATCH.

**Calendar views**: Show a subtle badge or indicator on official events (e.g. a small "PDA" tag or star icon on the event chip). Keep it minimal.

**Event detail panel**: Show "official PDA event" label for official events. The "give feedback" link (survey) already only shows when `survey_slugs` is non-empty, which naturally only happens for official events.

**Event management screen**: Add a filter toggle (all / official / community).

## Files to modify

- `backend/community/models.py` — `EventType`, field on `Event`
- `backend/community/api.py` — schemas + permission check in create/update
- `frontend/lib/models/event.dart` — add `eventType` field + codegen
- `frontend/lib/screens/calendar/event_form_dialog.dart` — official toggle
- `frontend/lib/screens/calendar/event_detail_panel.dart` — official badge
- `frontend/lib/screens/calendar/month_view.dart` — optional: badge on chips
- `frontend/lib/screens/event_management_screen.dart` — filter

## Verification

1. `make lint` + `make frontend-lint`
2. Create event as regular member → should be community type, can't toggle official
3. Create event as admin with manage_events → can toggle official
4. Link a survey to an official event → "give feedback" shows on event detail
5. Try to link survey to community event → should be rejected or option not shown
