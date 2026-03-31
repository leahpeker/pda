# Issue #150: Send credentials via SMS on join request approval

## Context
When an admin approves a join request, the backend already creates a user account with a temp password and returns it in the API response. The frontend shows it in a dialog for the admin to manually share. The issue asks us to automatically send the credentials to the approved user via text message, so the admin doesn't have to copy-paste and message them manually.

## What already works
- `PATCH /api/community/join-requests/{id}/` with `status: "approved"` creates a User via `_create_user_with_role()`, returns `temporary_password` in response
- Frontend shows `ApprovalCredentialsDialog` with phone + temp password
- Phone numbers are already validated to E.164 format via `phonenumbers` library

## SMS Provider Options

No SMS infrastructure exists today. We need to add a provider:

| Provider | Package | Pros | Cons |
|----------|---------|------|------|
| **Twilio** | `twilio` | Most popular, great docs, Python SDK, free trial with test credentials | Requires Twilio account + phone number, ~$0.0079/SMS |
| **Vonage (Nexmo)** | `vonage` | Competitive pricing, good Python SDK | Slightly less documentation |
| **AWS SNS** | `boto3` | No dedicated phone number needed for transactional SMS, pay-per-message | Heavier dependency (`boto3`), requires AWS account |

**Recommendation:** Twilio — best docs, easiest to set up, test credentials for dev.

## Changes

### 1. Add SMS dependency + settings
**File:** `pyproject.toml` — add chosen SMS package (e.g. `twilio`)

**File:** `backend/config/settings.py` — add SMS config from env vars:
```python
SMS_ACCOUNT_SID = os.environ.get("SMS_ACCOUNT_SID", "")
SMS_AUTH_TOKEN = os.environ.get("SMS_AUTH_TOKEN", "")
SMS_FROM_NUMBER = os.environ.get("SMS_FROM_NUMBER", "")
```

**File:** `.env.example` — add empty placeholders:
```
SMS_ACCOUNT_SID=
SMS_AUTH_TOKEN=
SMS_FROM_NUMBER=
```

### 2. Add `send_sms()` transport function
**File:** `backend/notifications/sms.py` (new)

Add `send_sms(to_number: str, message: str) -> bool`:
- Read `SMS_ACCOUNT_SID`, `SMS_AUTH_TOKEN`, `SMS_FROM_NUMBER` from settings
- Guard: return `False` if any are empty (not configured)
- Send via chosen provider's SDK
- Same best-effort pattern as `send_to_group` — return `False` on failure, log warning, never raise

### 3. Add `notify_approved_user()` service function
**File:** `backend/notifications/service.py`

Add `notify_approved_user(phone_number: str, display_name: str, temp_password: str) -> bool`:
- Compose a friendly welcome message
- Call `send_sms(phone_number, message)`

Message template:
```
hey {display_name}! welcome to pda 🌱

your account is ready — here are your login details:

phone: {phone_number}
temporary password: {temp_password}

you'll be asked to set a new password when you first log in.
```

### 4. Call notification from approval endpoint
**File:** `backend/community/api.py`

In `update_join_request_status()` (~line 648):
- After `_create_user_with_role()` returns, call `notify_approved_user()` (best-effort)
- Capture result as `sms_sent: bool`
- Add `sms_sent: bool = False` to `ApproveJoinRequestOut` schema (~line 121)
- Return `sms_sent` in the response

### 5. Update frontend to show SMS send status
**File:** `frontend/lib/screens/join_requests_screen.dart`

In `_updateStatus()` (~line 43): extract `sms_sent` from response data, pass to `_showApprovalModal`.

In `_showApprovalModal()` (~line 56): change `body` based on `smsSent`:
- `true` → `'credentials were sent to them via text 🌿'`
- `false` → `'share these login credentials with them:'` (existing copy)

No changes needed to `ApprovalCredentialsDialog` itself — it already accepts `title` and `body` as params.

### 6. Add tests

**File:** `backend/tests/test_notifications.py`

`TestSendSms` class:
- `test_sends_sms_when_configured` — mock the SMS client, verify message sent to correct number
- `test_returns_false_when_not_configured` — empty settings, no SDK call
- `test_returns_false_on_error` — SDK raises, returns False

`TestNotifyApprovedUser` class:
- `test_sends_welcome_message` — mock `send_sms`, verify message contains display name + password
- `test_returns_false_when_send_fails` — mock returns False, function returns False

**File:** `backend/tests/test_api.py` (in `TestJoinRequestManagement`)

- `test_approve_sends_sms_and_returns_status` — mock `send_sms` returning True, assert `sms_sent` is True
- `test_approve_succeeds_when_sms_fails` — mock returning False, assert approval still succeeds with `sms_sent` False

## Key files
- `backend/notifications/sms.py` — new SMS transport layer
- `backend/notifications/service.py` — service layer (add `notify_approved_user`)
- `backend/community/api.py` — approval endpoint + `ApproveJoinRequestOut` schema
- `backend/config/settings.py` — SMS settings
- `backend/tests/test_notifications.py` — notification tests
- `backend/tests/test_api.py` — join request management tests
- `frontend/lib/screens/join_requests_screen.dart` — approval UI

## Verification
- `make ci` passes
- Manual: approve a join request with SMS configured → user receives text with credentials, dialog shows "sent via text"
- Manual: approve with SMS not configured → dialog shows "share these login credentials" (fallback), approval still succeeds
