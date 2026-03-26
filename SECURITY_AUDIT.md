# Security Audit Report — PDA

**Date:** 2026-03-25
**Scope:** Full codebase — Django backend, Flutter frontend, infrastructure
**Severity summary:** 3 Critical · 6 High · 7 Medium · 4 Low · 4 Info

---

## Priority Action Items

### Critical (block production deployment)
1. Fix `ALLOWED_HOSTS = "*"` — set to explicit domain(s) via env var
2. Add HTTPS enforcement — `SECURE_SSL_REDIRECT=True`, HSTS headers
3. Fix Docker `SECRET_KEY` placeholder — use build-time random value
4. Fix CORS — set explicit `CORS_ALLOWED_ORIGINS` in production
5. Validate external URLs before `openUrl()` — reject `javascript:` and `data:` schemes

### High (required before public launch)
6. Add rate limiting on login and join request endpoints
7. Fix email error handling — alert loudly if vetting email fails
8. Create production env template with startup validation for required vars
9. Validate co-host IDs — return 400 if user not found

### Medium (within 2 weeks)
10. Remove temporary passwords from API responses (or send via secure email)
11. Omit phone numbers from vetting emails; link to admin dashboard instead
12. Fix refresh token exception handling — catch specific JWT exceptions, not bare `Exception`
13. Add timeout to token refresh Dio instance
14. Create deployment checklist

---

## Detailed Findings

### Backend

#### CRITICAL-1: `ALLOWED_HOSTS = ["*"]`
**File:** `backend/config/settings.py`

Disables Django's Host header validation. Enables host header injection, cache poisoning, virtual host confusion.

**Fix:**
```python
ALLOWED_HOSTS = os.environ.get("ALLOWED_HOSTS", "").split(",")
if IS_PRODUCTION and not ALLOWED_HOSTS[0]:
    raise ValueError("ALLOWED_HOSTS must be set in production")
```

---

#### CRITICAL-2: No HTTPS enforcement in production
**File:** `backend/config/settings.py` (missing settings)

`SECURE_SSL_REDIRECT`, `SECURE_HSTS_*`, `SESSION_COOKIE_SECURE`, `CSRF_COOKIE_SECURE` are all unset.

**Fix:**
```python
if IS_PRODUCTION:
    SECURE_SSL_REDIRECT = True
    SECURE_HSTS_SECONDS = 31536000
    SECURE_HSTS_INCLUDE_SUBDOMAINS = True
    SECURE_HSTS_PRELOAD = True
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
```

---

#### CRITICAL-3: Docker build hardcodes placeholder `SECRET_KEY`
**File:** `Dockerfile`

```dockerfile
RUN DJANGO_SETTINGS_MODULE=config.settings \
    SECRET_KEY=collectstatic-placeholder \
    uv run python backend/manage.py collectstatic --noinput
```

If the image is run without a real `SECRET_KEY` set, the app starts with a known secret — JWT tokens can be forged.

**Fix:** Generate a random value at build time:
```dockerfile
RUN SECRET_KEY=$(python -c "import secrets; print(secrets.token_urlsafe(32))") \
    DJANGO_SETTINGS_MODULE=config.settings \
    uv run python backend/manage.py collectstatic --noinput
```

---

#### HIGH-1: CORS allows all origins in production
**File:** `backend/config/settings.py`

`CORS_ALLOWED_ORIGINS` is only set for dev. In production, `django-cors-headers` defaults to allowing all origins.

**Fix:**
```python
if IS_PRODUCTION:
    CORS_ALLOWED_ORIGINS = os.environ.get("CORS_ALLOWED_ORIGINS", "").split(",")
else:
    CORS_ALLOWED_ORIGINS = ["http://localhost:3000"]
```

---

#### HIGH-2: Unvalidated external URLs in event links
**File:** `backend/community/models.py`, `frontend/lib/utils/launcher_web.dart`

`whatsapp_link`, `partiful_link`, `other_link` accept any URL. Django's `URLField` allows `javascript:` and `data:` schemes. The frontend's `openUrl()` opens URLs without validation.

**Fix (backend):**
```python
from urllib.parse import urlparse
from django.core.validators import URLValidator

class SafeURLValidator(URLValidator):
    def __call__(self, value):
        super().__call__(value)
        if urlparse(value).scheme not in ('http', 'https', 'tel', 'mailto'):
            raise ValidationError(f"URL scheme not allowed")
```

**Fix (frontend):**
```dart
const Set<String> _safeSchemes = {'http', 'https', 'tel', 'mailto'};

void openUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !_safeSchemes.contains(uri.scheme)) return;
  web.window.open(url, '_blank');
}
```

---

#### HIGH-3: Email failure is silent
**File:** `backend/community/api.py`

Join request always returns 201 even if the vetting email fails. Admins never learn about new requests if email is misconfigured.

**Fix:** Log a structured warning and consider returning a warning in the response body:
```python
try:
    send_mail(..., fail_silently=False)
except Exception:
    logger.exception("Failed to send vetting email for join request %s", join_request.id)
    # Optionally: return partial success with warning in response
```

---

#### HIGH-4: Refresh token catches bare `Exception`
**File:** `backend/users/api.py`

```python
except Exception:
    return Status(401, ErrorOut(detail="Invalid or expired refresh token"))
```

Database failures, library bugs, and other unexpected errors are silently swallowed and returned as 401.

**Fix:**
```python
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError

except (InvalidToken, TokenError):
    return Status(401, ErrorOut(detail="Invalid or expired refresh token"))
except Exception:
    logger.exception("Unexpected error during token refresh")
    raise
```

---

#### HIGH-5: No rate limiting on auth/join endpoints
**File:** `backend/users/api.py`, `backend/community/api.py`

Login and join request endpoints allow unlimited attempts. Login is vulnerable to brute force; join is vulnerable to inbox flooding.

**Fix:** Add `django-ratelimit` or Railway's built-in request limits:
```python
@ratelimit(key='ip', rate='5/m', method='POST', block=True)
@router.post("/login/", ...)
```

---

#### MEDIUM-1: Temporary passwords returned in API response
**File:** `backend/users/api.py`

Plaintext passwords appear in the HTTP response body. If responses are logged, cached, or intercepted, the password is exposed.

**Fix:** Generate password server-side, show it only in the UI (not via an API field), or send it to the user via secure email. Never store or return plaintext passwords after creation.

---

#### MEDIUM-2: Phone numbers in plaintext vetting emails
**File:** `backend/community/api.py`

Join request emails include the submitter's phone number. Email servers and backups may store this PII indefinitely.

**Fix:** Replace phone number with a link to the admin dashboard:
```python
message=f"New join request from {display_name}.\nReview: https://yourdomain.com/admin/community/joinrequest/{join_request.id}/change/"
```

---

#### MEDIUM-3: No timeout on token refresh Dio instance
**File:** `frontend/lib/services/api_client.dart`

The Dio instance used for token refresh has no connect/receive timeout. A hanging backend blocks all subsequent requests indefinitely.

**Fix:**
```dart
final response = await Dio(BaseOptions(
  baseUrl: apiBaseUrl,
  connectTimeout: const Duration(seconds: 10),
  receiveTimeout: const Duration(seconds: 10),
)).post('/api/auth/refresh/', data: {'refresh': refresh});
```

---

#### MEDIUM-4: `.env` file in git
**File:** `.env`

The `.env` file is tracked. If it ever contained real credentials, they are in git history permanently.

**Action:**
1. Verify no real secrets were ever committed: `git log --all --oneline -- .env`
2. Add `.env` to `.gitignore`
3. If real secrets were committed, rotate all of them and scrub git history with BFG

---

#### MEDIUM-5: No production env validation at startup
**File:** `backend/config/settings.py`, `Dockerfile`

The app can start without `ALLOWED_HOSTS`, `VETTING_EMAIL`, `CORS_ALLOWED_ORIGINS`, etc. Misconfiguration is silent.

**Fix:** Fail fast:
```python
if IS_PRODUCTION:
    for var in ["SECRET_KEY", "DATABASE_URL", "ALLOWED_HOSTS"]:
        if not os.environ.get(var):
            raise ValueError(f"{var} must be set in production")
```

---

#### LOW-1: Event co-host IDs not validated
**File:** `backend/community/api.py`

`filter(pk__in=...)` silently drops non-existent IDs. No error is returned if a co-host UUID doesn't exist.

**Fix:** Compare count before/after and return 400 if any IDs are missing.

---

#### LOW-2: JWT access token lifetime
**File:** `backend/config/settings.py`

15-minute access token is reasonable but could be reduced to 5 minutes for a more security-sensitive app.

---

#### LOW-3: Password minimum length is 8 characters
**File:** `backend/config/settings.py`

Consider raising to 12 characters in `MinimumLengthValidator`.

---

#### LOW-4: No certificate pinning (Flutter)
**File:** `frontend/lib/services/api_client.dart`

Standard HTTPS without cert pinning. Acceptable for web; low priority since the Flutter app is primarily a web app.

---

### Positive Findings (maintain these)

- **Phone number validation** uses the `phonenumbers` library — full E.164 normalization and country validation
- **PII redaction in logs** — tokens, passwords, phone numbers stripped from log output
- **Secure storage** — Flutter uses `flutter_secure_storage` (Keychain/Keystore), no plaintext tokens
- **Role-based permissions** — all protected endpoints check `hasPermission()`
- **WhiteNoise** — correctly configured with compressed, cache-busted static files
- **JWT token lifetimes** — short access (15m), longer refresh (7d) stored securely
- **Input validation** — join request fields validated with regex and required-field checks

---

## References

- [Django security checklist](https://docs.djangoproject.com/en/stable/howto/deployment/checklist/)
- [OWASP API Security Top 10](https://owasp.org/www-project-api-security/)
- [flutter_secure_storage docs](https://pub.dev/packages/flutter_secure_storage)
