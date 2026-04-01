# Plan: feat: list view of all events (#185)

## Approach

Add a 4th "list" mode toggle to `CalendarScreen` (alongside month/week/day). The list view is a public-accessible, filterable, sortable events list — no new route needed.

## Files to Change

| File | Action |
|------|--------|
| `frontend/lib/screens/calendar_screen.dart` | Add `list` to `_CalendarView` enum, add segment, add case, conditionally hide "today" button |
| `frontend/lib/screens/calendar/list_view.dart` | **Create**: `EventListView` widget with filters + `_EventListRow` |
| `frontend/test/accessibility/calendar_views_a11y_test.dart` | Add `EventListView` accessibility group |
| `frontend/test/screens/calendar_screen_test.dart` | Update "renders month/week/day" test to include "list" |
| `frontend/test/screens/calendar/list_view_test.dart` | **Create**: widget tests for filter/sort/navigation |

## Implementation Details

### CalendarScreen changes
- `enum _CalendarView { month, week, day, list }`
- Add `ButtonSegment(value: _CalendarView.list, label: Text('list'))` to toolbar
- Add `case _CalendarView.list: return EventListView(events: events)` in `_buildView`
- Hide "today" AppBar button when `_view == _CalendarView.list`

### EventListView widget
- `StatefulWidget` (not Consumer — receives events via constructor)
- State: `_query`, `_typeFilter` (null/official/community), `_showUpcoming` (bool), `_sortAscending` (bool)
- Filter logic: title search → type filter → upcoming/past split → sort by startDatetime
- Upcoming = `(event.endDatetime ?? event.startDatetime).isAfter(DateTime.now())`
- Layout: search bar → filter row (type SegmentedButton + upcoming/past toggle + sort icon) → results count → list body
- Filter row wrapped in `SingleChildScrollView(scrollDirection: Axis.horizontal)` for narrow screens
- Empty states: `'no matches for "$_query"'`, `'nothing upcoming 🌿'`, `'no past events'`

### _EventListRow widget
- Based on `_DayEventCard` pattern (accessibility) + `_EventManagementRow` layout (date shown, no edit/delete)
- `Semantics(button: true, label: event.title, excludeSemantics: true)` wrapping `InkWell`
- `onTap: () => context.push('/events/${event.id}')`
- Shows: title + official badge, date+time, location (if any), hosts line

## Tests
- Accessibility: event rows have semantic labels, `labeledTapTargetGuideline`, `androidTapTargetGuideline`
- Widget: renders events, search filter, type filter, upcoming/past toggle, sort asc/desc, empty state, tap navigates
