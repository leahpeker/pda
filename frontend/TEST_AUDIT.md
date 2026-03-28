# Frontend Test Audit

## Current State

18 test files total. Coverage is heavily skewed toward accessibility audits and layout algorithm unit tests. Core business logic (providers, screen flows) is largely untested.

---

## What Exists

### Providers (2 files)
- `auth_provider_test.dart` — error handling for login (invalid credentials, network error, server error). No success case.
- `join_request_provider_test.dart` — error handling for join request submission. No success case.

### Services (3 files)
- `api_error_test.dart` — complete coverage of `ApiError.from()` factory
- `error_reporter_test.dart` — error reporting to backend with fallback logging
- `app_logger_test.dart` — logging setup and AppLogger singleton

### Screens (3 files)
- `login_screen_test.dart` — autofill hints, password visibility toggle, empty field validation. No success/error flow.
- `month_placement_calculator_test.dart` — thorough unit tests for month layout algorithm
- `week_placement_calculator_test.dart` — thorough unit tests for week layout algorithm

### Router (2 files)
- `app_router_test.dart` — single test for router instance preservation across auth state changes
- `app_router_semantics_test.dart` — all GoRoutes have semantic names

### Accessibility (7 files)
- `semantics_test.dart` — JoinScreen and LoginScreen button/field semantics
- `guidelines_test.dart` — WCAG compliance (contrast, tap targets) for JoinScreen and LoginScreen
- `calendar_views_a11y_test.dart` — event chip semantics in WeekView and DayView
- `month_view_a11y_test.dart` — day cell labels, event chip semantics
- `focus_traversal_test.dart` — FocusTraversalGroup on JoinScreen and LoginScreen
- `gesture_detector_audit_test.dart` — scans for unapproved bare GestureDetector usage
- `app_scaffold_a11y_test.dart` — drawer semanticLabel on macOS/iOS

### Smoke (1 file)
- `widget_test.dart` — app renders without crashing, semantics enabled

---

## Gaps

### Providers with zero coverage
| Provider | What it does |
|----------|-------------|
| `event_provider.dart` | Fetches event list; watches auth state for reload |
| `guidelines_provider.dart` | Fetches guidelines content |
| `home_provider.dart` | Fetches landing page content + donate URL |
| `join_request_management_provider.dart` | Admin approve/reject join requests |
| `user_management_provider.dart` | Member list, search, create, bulk create |
| `editable_page_provider.dart` | Fetch + save editable page content |

### Screens with zero functional coverage
| Screen | Notes |
|--------|-------|
| `home_screen.dart` | No tests at all |
| `join_screen.dart` | A11y only; no form submission, validation, or nav to /join/success |
| `join_success_screen.dart` | No tests |
| `calendar_screen.dart` | No tests |
| `event_detail_screen.dart` | No tests |
| `event_management_screen.dart` | No tests (admin CRUD) |
| `guidelines_screen.dart` | No tests |
| `donate_screen.dart` | No tests |
| `members_screen.dart` | No tests |
| `join_requests_screen.dart` | No tests |
| `volunteer_screen.dart` | No tests |
| `settings_screen.dart` | No tests |

### Shallow tests (exist but incomplete)
- `widget_test.dart` — just a crash guard, no real flows
- `app_router_test.dart` — single bug-fix regression test, no routing logic coverage
- `login_screen_test.dart` — UI features only; missing: successful login, error display, redirect to /calendar
- All accessibility tests — structural checks only, no functional behavior

---

## What to Add

### Priority 1 — Provider unit tests

**`test/providers/event_provider_test.dart`** (new)
- Successful fetch returns list of events
- Unauthenticated fetch returns public events (no links/RSVP)
- Authenticated fetch returns full event data
- Network error → AsyncError state
- Provider invalidates and refetches when authProvider changes

**`test/providers/auth_provider_test.dart`** (expand)
- Add success case: login sets `AsyncData<User>` with correct user
- Add: successful logout clears state

**`test/providers/join_request_management_provider_test.dart`** (new)
- Fetch list of join requests
- Approve request → optimistic/confirmed state update
- Reject request → state update
- Error handling

**`test/providers/user_management_provider_test.dart`** (new)
- Fetch member list
- Search returns filtered results
- Create user success
- Bulk create success + partial failure
- Error handling

**`test/providers/guidelines_provider_test.dart`** (new)
- Fetch returns content
- Save content updates state
- Error handling

**`test/providers/home_provider_test.dart`** (new)
- Fetch returns content + donate URL
- Save updates state

---

### Priority 2 — Screen functional tests

**`test/screens/auth/login_screen_test.dart`** (expand)
- Successful login → navigates to /calendar
- Failed login → error message shown
- Failed login → form stays populated
- Login while loading → button disabled

**`test/screens/join_screen_test.dart`** (new functional tests)
- Submitting valid form → navigates to /join/success
- Submitting invalid form → inline validation errors
- Network error → error message shown

**`test/screens/home_screen_test.dart`** (new)
- Renders default content while loading
- Renders fetched content
- Donate CTA shown when donateUrl set; hidden when empty
- Edit mode shown for admin; hidden for regular user

**`test/screens/calendar_screen_test.dart`** (new)
- Renders month/week/day view toggle
- Events appear in the correct view
- Tapping an event opens the detail panel

**`test/screens/event_detail_screen_test.dart`** (new)
- Event title, date, location render
- Links shown for authenticated users; hidden for guests
- RSVP section shown when rsvpEnabled and authenticated

**`test/screens/members_screen_test.dart`** (new)
- Member list renders
- Search filters results
- Requires manage_users permission (redirect otherwise)

---

### Priority 3 — Integration / flow tests

**`test/flows/auth_flow_test.dart`** (new)
- Login → redirect to /calendar
- Visit protected route unauthenticated → redirect to /login with redirect param
- After login, redirect param followed correctly
- Logout → redirect to /

**`test/flows/join_flow_test.dart`** (new)
- Fill form → submit → land on /join/success
- Navigate away from success → landing page

---

### Priority 4 — Widget tests

**`test/widgets/event_detail_panel_test.dart`** (new)
- Renders event details
- Links hidden for unauthenticated user
- RSVP section renders when enabled
- Admin actions shown for event creator

**`test/widgets/app_scaffold_test.dart`** (expand existing a11y test)
- Nav drawer opens on mobile
- Correct route highlighted as active
- Logout item shown when authenticated; login shown when not

---

## Test Infrastructure Notes

- All provider tests should use `ProviderContainer` with overridden `apiClientProvider` (mock Dio)
- Use `mockito` or manual fakes — project currently has no mock library listed; may need to add `mocktail` or `mockito` to `dev_dependencies`
- Screen tests should use `pumpWidget` with a `ProviderScope` wrapping a `MaterialApp`
- For router tests, use `GoRouter` with a test observer or just verify navigation via `GoRouterState`
- The existing `FakeSecureStorage` helper in `test/helpers/` can be reused for auth tests
