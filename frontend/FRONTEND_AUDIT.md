# Frontend Audit — March 2026

## Shared Components Inventory

**`frontend/lib/widgets/`**

| Widget | Purpose |
|--------|---------|
| `AppScaffold` | App shell with nav drawer/topbar, onboarding modal trigger |
| `AutosaveMixin` + `AutosaveIndicator` | Debounced autosave with status indicator |
| `EditableContentBlock` | Editable content page with admin toolbar (used by donate/volunteer screens) |
| `OnboardingModal` | First-login setup form |
| `PhoneFormField` | IntlPhoneField wrapper with E.164 validation |
| `QuillContentEditor` | Rich text view + edit mode |
| `TempPasswordField` | Display/copy temp password with visibility toggle |

---

## Duplication

### Save/Cancel button row — 7+ occurrences
The edit/cancel/save trio with loading spinner is copy-pasted across:
- `home_screen.dart` (twice — `_EditableSection` and `_DonateCta`)
- `guidelines_screen.dart`
- `editable_content_block.dart`
- `settings_screen.dart`
- `members_screen.dart` (multiple)

All follow the same shape: `FilledButton.tonal('Edit')` → `[TextButton('Cancel'), FilledButton('Save' / spinner)]`.

Could extract to a `SaveCancelButtonRow` widget.

### Loading button spinner — 9 occurrences
```dart
_saving
  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
  : const Text('Save')
```
Could be a small helper widget or function.

### Error snackbar — 12 occurrences
`ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(...)))` scattered everywhere. Could be a `showErrorSnackBar(context, message)` utility in `utils/`.

### DioException detail extraction — 5 occurrences
```dart
(e.response?.data as Map?)?['detail'] as String? ?? 'Fallback message'
```
Found in `editable_content_block.dart`, `home_screen.dart` (×2), `guidelines_screen.dart`. Note: some screens already use `ApiError.from(e)` — should standardize on that.

### Approval/credentials dialog — 2 occurrences
`join_requests_screen.dart` (`_showApprovalModal`) and `members_screen.dart` (`_showCreatedPasswordDialog`) both display a dialog with display name, phone, `TempPasswordField`, and instructions. Could share an `ApprovalCredentialsDialog` widget.

---

## Inconsistencies

### Button styles
- `home_screen.dart` uses `ElevatedButton` for "Request to join" — should be `FilledButton` to match every other primary action in the app.
- Error snackbars: most are plain, but `members_screen.dart` adds `backgroundColor: Colors.red` on one. Should pick one style.

### Error handling
Some screens catch `DioException` and extract `detail` manually; others use `ApiError.from(e).message`. `settings_screen.dart` does both in different methods. Should standardize on `ApiError.from(e).message`.

---

## Oversized Files

Files exceeding the 300-line guideline:

| File | Lines | Notes |
|------|-------|-------|
| `event_detail_panel.dart` | ~1691 | Contains `EventFormDialog`, `_RSVPSection`, `_RsvpButton`, helpers all in one file |
| `members_screen.dart` | ~1342 | Members tab, roles tab, role editor, role form, bulk-add dialog all together |
| `join_requests_screen.dart` | ~373 | Filter chips, card, status badge, info row |
| `home_screen.dart` | ~364 | `_EditableSection`, `_DonateCta`, footer |
| `settings_screen.dart` | ~420 | Profile section, security section, multiple dialogs |

Most impactful splits:
- Move `EventFormDialog` → `event_form_dialog.dart`
- Move `_RSVPSection` → `rsvp_section.dart`
- Split `members_screen.dart` into members list, roles tab, role form

---

## Dead Code

- **`members_screen.dart`**: imports `intl_phone_field` but never uses `IntlPhoneField` directly — uses `PhoneFormField` wrapper instead. Dead import.

---

## Minor Issues

- A few `IconButton` widgets are missing `tooltip:` parameters (accessibility rule requires all icon buttons have tooltips).
- Hard-coded colors in `event_detail_panel.dart` (RSVP status: `Colors.green`, `Colors.orange`, `Colors.red`) and `join_requests_screen.dart` (`_statusColor()`) — should use theme colors.
- Mixed font sizes (`13.0`, `14.0`, `15.0`, `16.0`) used inline rather than `Theme.of(context).textTheme.*`.

---

## What's Already Good

- No `withOpacity()` — all uses are `withValues(alpha:)` ✓
- No bare `GestureDetector` for user-facing interactions ✓
- `Semantics` labels on all custom tappable widgets ✓
- `FocusTraversalGroup` + `NumericFocusOrder` in forms ✓
- `Drawer` has `semanticLabel` ✓
- One provider per file, consistently named ✓
