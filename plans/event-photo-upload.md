# feat: event photo upload

## Context

Events currently have no photos. Adding a cover photo per event makes the calendar and event details more visually engaging. Reuses the Backblaze B2 storage infrastructure from the profile photo feature (#63).

## Design decisions

- **One photo per event** (not a gallery) — keeps it simple, can add multi-photo later
- **Separate upload endpoint** (not multipart on create/edit) — matches the profile photo pattern, avoids reworking the existing JSON-only event create/update flow
- **Photo shows in detail panel only** — calendar chips (month/week) are too compact for images. Day view could optionally show a thumbnail.
- **Upload lives in the event detail panel** — after creating an event, you can add/change the photo from the detail view. Creators and manage_events users can upload.

## Backend

### Model (`backend/community/models.py`)

Add to `Event`:
```python
photo = models.ImageField(upload_to="event_photos/", blank=True)
```
Migration needed.

### Schemas (`backend/community/api.py`)

Add `photo_url: str = ""` to both `EventOut` and `EventListOut`.

In `_event_out()`, set: `photo_url=event.photo.url if event.photo else ""`

In the list endpoint, set: `photo_url=e.photo.url if e.photo else ""`

### Endpoints (`backend/community/api.py`)

**`POST /events/{event_id}/photo/`** — upload event photo
- Auth: JWTAuth
- Permission: creator or manage_events (same as edit)
- Accepts: `UploadedFile` (reuse `_ALLOWED_IMAGE_TYPES`, `_MAX_PHOTO_SIZE` constants from users/api.py — or define shared constants)
- Deletes old photo, saves new one as `{event_id}.{ext}`
- Returns updated `EventOut`

**`DELETE /events/{event_id}/photo/`** — remove event photo
- Same permission check
- Returns updated `EventOut`

## Frontend

### Event model (`frontend/lib/models/event.dart`)

Add `@Default('') String photoUrl` + run codegen.

### Event provider (`frontend/lib/providers/event_provider.dart`)

Add methods:
```dart
Future<void> uploadEventPhoto(String eventId, XFile file) async { ... }
Future<void> deleteEventPhoto(String eventId) async { ... }
```
Both invalidate `eventsProvider` + `eventDetailProvider(eventId)` after success.

### Event detail panel (`frontend/lib/screens/calendar/event_detail_panel.dart`)

- When `photoUrl` is non-empty: show a banner image at the top of the detail panel (before title), with rounded corners, constrained to ~200px height
- In the admin actions section: add a photo upload button (camera icon) that opens `ImagePicker`, calls `uploadEventPhoto`
- If photo exists: show a small "remove photo" option

### Event form dialog (`frontend/lib/screens/calendar/event_form_dialog.dart`)

Add a photo picker section at the top of the form (below title, above no-fees note):
- Shows a tappable image preview area (dashed border placeholder when empty, thumbnail when selected)
- Opens `ImagePicker` on tap
- Stores selected `XFile?` in local state
- When editing an event with an existing photo, shows the current photo as preview with an "x" to remove

The form dialog returns a result class instead of a raw map — something like:
```dart
class EventFormResult {
  final Map<String, dynamic> data;
  final XFile? photo;
  final bool removePhoto;
}
```

The callers (`_openCreateEvent` in calendar_screen, `_edit` in event_detail_panel) then:
1. POST/PATCH the JSON data as before
2. If `result.photo != null`, follow up with `uploadEventPhoto(eventId, photo)`
3. If `result.removePhoto`, call `deleteEventPhoto(eventId)`

## Files to modify

- `backend/community/models.py` — add `photo` field
- `backend/community/api.py` — schemas + upload/delete endpoints
- `frontend/lib/models/event.dart` — add `photoUrl` + codegen
- `frontend/lib/providers/event_provider.dart` — upload/delete methods
- `frontend/lib/screens/calendar/event_detail_panel.dart` — banner image + upload UI in admin actions
- `frontend/lib/screens/calendar/event_form_dialog.dart` — photo picker in form + `EventFormResult` return type
- `frontend/lib/screens/calendar_screen.dart` — update `_openCreateEvent` to handle photo after create
- `frontend/lib/screens/event_management_screen.dart` — if it has inline create, same treatment

## Verification

1. `make lint` + `make frontend-lint`
2. Create event → open detail → upload photo → photo shows as banner
3. Edit photo → old one replaced
4. Delete photo → banner disappears
5. Photo URL returned in event list and detail API responses
