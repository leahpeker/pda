# Proxy B2 media through Django

## Context

Profile photos and event photos are stored on Backblaze B2. The API returns absolute B2 URLs (`https://s3.us-east-005.backblazeb2.com/pda-prod/...`) to the Flutter frontend. These B2 URLs timeout on most devices due to SSL/connectivity issues with B2's S3-compatible endpoint. The fix is to proxy images through Django so the frontend requests them from the app's own domain. This also allows making the B2 bucket private afterward.

## Key insight

`django-storages` S3Storage's `.url()` method ignores `MEDIA_URL` — it generates URLs from `endpoint_url` or `custom_domain`. Rather than fighting this, we replace all `field.url` calls with a helper that returns `/media/{field.name}`, and add a Django view at `/media/` that streams files from whatever storage backend is configured.

## Changes

### 1. Add a media URL helper — `backend/config/media_proxy.py` (new file)

```python
def media_path(field) -> str:
    """Return a relative /media/ URL for a FileField, or '' if empty."""
    if not field:
        return ""
    return f"/media/{field.name}"
```

### 2. Add the proxy view — same file

```python
def serve_media(request, path):
    if not default_storage.exists(path):
        raise Http404
    f = default_storage.open(path)
    content_type, _ = mimetypes.guess_type(path)
    response = FileResponse(f, content_type=content_type or "application/octet-stream")
    response["Cache-Control"] = "public, max-age=86400, immutable"
    return response
```

- Uses `default_storage` — in dev reads from disk, in prod reads from B2 via the S3 API (server-side, no SSL issue)
- `FileResponse` streams in chunks (no full file in memory)
- 24h browser cache since filenames contain UUIDs

### 3. Wire the URL — `backend/config/urls.py`

- Add `re_path(r"^media/(?P<path>.+)$", serve_media)` before the SPA catch-all
- Remove the `if settings.DEBUG: static(...)` block (the proxy replaces it)

### 4. Replace `field.url` with `media_path(field)` — 6 call sites

| File | Line | Current | New |
|------|------|---------|-----|
| `backend/users/api.py` | ~174 | `user.profile_photo.url if user.profile_photo else ""` | `media_path(user.profile_photo)` |
| `backend/users/api.py` | ~391 | same pattern | `media_path(user.profile_photo)` |
| `backend/community/api.py` | ~843 | `r.user.profile_photo.url if r.user.profile_photo else ""` | `media_path(r.user.profile_photo)` |
| `backend/community/api.py` | ~895 | `u.profile_photo.url if u.profile_photo else ""` | `media_path(u.profile_photo)` |
| `backend/community/api.py` | ~900 | `event.photo.url if event.photo else ""` | `media_path(event.photo)` |
| `backend/community/api.py` | ~927 | `e.photo.url if e.photo else ""` | `media_path(e.photo)` |

### 5. Clean up `settings.py`

- Remove line 122: `MEDIA_URL = f"{os.environ['B2_ENDPOINT_URL']}/{os.environ['B2_BUCKET_NAME']}/"` (no longer used)

### 6. Tests — `backend/tests/test_photos.py`

Add `TestMediaProxy` class:
- `test_serves_uploaded_photo` — upload via existing endpoint, GET the returned URL, assert 200 + correct content type + Cache-Control header
- `test_404_for_missing_file` — GET `/media/nonexistent.jpg`, assert 404
- `test_path_traversal_blocked` — GET `/media/../settings.py`, assert 404

Existing photo tests should still pass (they check `!= ""`, not URL format).

### 7. No frontend changes needed

In production, same-origin — `NetworkImage('/media/...')` resolves against `proteindeficientsanonymous.com`. In dev, images already don't load cross-port (pre-existing issue, not a regression).

## Follow-up (separate steps, after verifying proxy works in prod)

1. Remove `default_acl: "public-read"` and `querystring_auth: False` from STORAGES config
2. Make the B2 bucket private in B2 console

## Optional enhancement: Cloudflare CDN

Three options to consider if we want to reduce load on Railway:

- **Cloudflare → B2 directly**: Set up a subdomain (e.g. `media.proteindeficientsanonymous.com`) pointing to B2 via Cloudflare. Free egress via Bandwidth Alliance. Django returns URLs using that subdomain. No Django proxy needed.
- **Cloudflare → Django → B2**: Keep the proxy but put Cloudflare in front of the whole domain. Cloudflare caches `/media/` responses via Cache-Control headers.
- **No CDN**: Just the proxy with browser caching (24h). Simplest, can add Cloudflare later.

## Verification

1. `make test` — all existing tests pass + new proxy tests pass
2. `make lint` — clean
3. Manual: upload a profile photo in dev, confirm `/media/profile_photos/...` returns the image
4. After deploy: confirm photos load on all devices via the app's own domain
