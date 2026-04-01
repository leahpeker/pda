# feat: add price + payment links to events (#204)

## Context

Events need a way to show costs (for shared orders/direct costs only — not profit) and payment links (Venmo, CashApp, Zelle). Payment fields should be hidden by default and only expand when the user taps "add cost".

## Backend

### Model (`backend/community/models.py`)
Add to Event:
```python
price = models.CharField(max_length=100, blank=True)
venmo_link = models.URLField(blank=True)
cashapp_link = models.URLField(blank=True)
zelle_link = models.CharField(max_length=200, blank=True)  # Zelle has no URL, just email/phone
```

### Schemas (`backend/community/api.py`)
Add `price`, `venmo_link`, `cashapp_link`, `zelle_link` to `EventOut`, `EventListOut`, `EventIn`, `EventPatchIn`. Payment links gated behind `_members_only()` like existing links. Price is public (so people know the cost before signing up).

### Migration needed.

## Frontend

### Event model (`frontend/lib/models/event.dart`)
Add 4 fields + codegen.

### Event form dialog (`frontend/lib/screens/calendar/event_form_dialog.dart`)

**Collapsible cost section:**
- By default: just a text button "add cost" (like "add end time" pattern)
- When tapped: expands to show:
  - Price field (free text, e.g. "$5 for groceries")
  - Venmo link
  - CashApp link
  - Zelle (email/phone, not a URL)
- If editing an event that already has a price, start expanded
- A "remove cost" button to collapse and clear all fields

**Update no-fees note:** Reiterate that costs should only cover shared orders/direct costs — no profit.

### Event detail panel (`frontend/lib/screens/calendar/event_detail_panel.dart`)

In the details section card:
- Show price as a `_DetailRow` with money icon (public, always visible)
- Show payment links as `_LinkRow` widgets (members-only, like other links)
- Zelle shows as copyable text (not a link since there's no URL)

### Constants (`frontend/lib/config/constants.dart`)
Add `EventDetailLabel.cost = 'cost'` if using a separate section card.

## Files to modify
- `backend/community/models.py`
- `backend/community/api.py`
- `frontend/lib/models/event.dart`
- `frontend/lib/screens/calendar/event_form_dialog.dart`
- `frontend/lib/screens/calendar/event_detail_panel.dart`
- `frontend/lib/config/constants.dart`
