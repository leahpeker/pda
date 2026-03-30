# feat: profile photo upload with Backblaze B2 (issue #63)

**Decision**: Backblaze B2 over Railway Buckets — B2 has 10 GB free tier, Railway Buckets are $0.015/GB with no free tier and no public bucket support (would need presigned URLs or a proxy for every image). B2 supports public-read ACL natively.

## Context

Members need profile photos. Photos need cloud storage since Railway's filesystem is ephemeral. Backblaze B2 is the best option — effectively free at our scale (10 GB free tier), doesn't eat into Railway's $10 Hobby plan cap, and has free egress via Cloudflare.

## Backblaze B2 Setup Instructions

### 1. Create a Backblaze account
- Go to https://www.backblaze.com/sign-up/cloud-storage
- Sign up (free, no credit card needed for the free tier)

### 2. Create a bucket
- Dashboard → Buckets → Create a Bucket
- **Bucket name**: `pda-media` (must be globally unique — try `pda-media-prod` if taken)
- **Files in bucket are**: **Public** (so profile photos can be served without signed URLs)
- **Default encryption**: Disable (not needed for public profile photos)
- **Object Lock**: Disabled
- Click "Create a Bucket"
- Note the **Endpoint** shown (e.g. `s3.us-west-004.backblazeb2.com`) — you'll need the region part (`us-west-004`)

### 3. Create an application key
- Dashboard → App Keys → Add a New Application Key
- **Name**: `pda-django`
- **Allow access to bucket**: Select your `pda-media` bucket
- **Type of access**: Read and Write
- Click "Create New Key"
- **Save both values immediately** (the application key is only shown once):
  - `keyID` → this is your access key ID
  - `applicationKey` → this is your secret key

### 4. Add env vars to Railway
In your Railway service settings, add:
```
B2_KEY_ID=<your keyID>
B2_APPLICATION_KEY=<your applicationKey>
B2_BUCKET_NAME=pda-media
B2_ENDPOINT_URL=https://s3.us-west-004.backblazeb2.com
B2_REGION=us-west-004
```

### 5. (Optional) Cloudflare CDN for free egress
- Add a CNAME record: `media.yourdomain.com` → `pda-media.s3.us-west-004.backblazeb2.com`
- In Cloudflare, enable proxying (orange cloud) — egress through Cloudflare is free via Bandwidth Alliance
- Set `B2_CUSTOM_DOMAIN=media.yourdomain.com` if using this

## Code Changes

### Backend

#### Dependencies (`pyproject.toml`)
Add: `django-storages[s3]`, `boto3`, `Pillow`

#### User model (`backend/users/models.py`)
Add field:
```python
profile_photo = models.ImageField(upload_to="profile_photos/", blank=True)
```
Migration `0009`.

#### Settings (`backend/config/settings.py`)

**Dev (local storage)**:
```python
MEDIA_URL = "/media/"
MEDIA_ROOT = BASE_DIR / "media"
```

**Prod (B2 via django-storages)**:
```python
if os.environ.get("B2_KEY_ID"):
    STORAGES = {
        "default": {
            "BACKEND": "storages.backends.s3.S3Storage",
            "OPTIONS": {
                "access_key": os.environ["B2_KEY_ID"],
                "secret_key": os.environ["B2_APPLICATION_KEY"],
                "bucket_name": os.environ["B2_BUCKET_NAME"],
                "endpoint_url": os.environ["B2_ENDPOINT_URL"],
                "region_name": os.environ.get("B2_REGION", "us-west-004"),
                "default_acl": "public-read",
                "querystring_auth": False,
            },
        },
        "staticfiles": {
            "BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage",
        },
    }
    MEDIA_URL = f"{os.environ['B2_ENDPOINT_URL']}/{os.environ['B2_BUCKET_NAME']}/"
```

#### URL config (`backend/config/urls.py`)
For local dev media serving:
```python
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
```

#### API endpoints (`backend/users/api.py`)

**Add to `UserOut`**: `profile_photo_url: str = ""`

**New endpoint** `POST /api/auth/me/photo/`:
- Auth: JWTAuth
- Accepts: multipart file upload (`UploadedFile`)
- Validates: file is an image, max 5 MB
- Saves to `user.profile_photo`
- Returns updated `UserOut`

**New endpoint** `DELETE /api/auth/me/photo/`:
- Auth: JWTAuth
- Clears the profile photo
- Returns updated `UserOut`

#### .env.example
Add (empty placeholders per convention):
```
B2_KEY_ID=
B2_APPLICATION_KEY=
B2_BUCKET_NAME=
B2_ENDPOINT_URL=
B2_REGION=
```

### Frontend

#### Dependencies (`pubspec.yaml`)
Add: `image_picker` (for selecting photos on web/mobile)

#### User model (`frontend/lib/models/user.dart`)
Add: `@Default('') String profilePhotoUrl` + run codegen

#### Auth provider (`frontend/lib/providers/auth_provider.dart`)
Add method:
```dart
Future<void> uploadProfilePhoto(XFile file) async {
  final api = ref.read(apiClientProvider);
  final formData = FormData.fromMap({
    'photo': await MultipartFile.fromFile(file.path, filename: file.name),
  });
  final response = await api.post('/api/auth/me/photo/', data: formData);
  state = AsyncData(User.fromJson(response.data));
}
```

#### Settings screen (`frontend/lib/screens/settings_screen.dart`)
Update `_ProfileAvatar`:
- Accept `photoUrl` and `onTap` params
- Show `CircleAvatar(backgroundImage: NetworkImage(photoUrl))` when non-empty
- On tap: open `ImagePicker().pickImage(source: ImageSource.gallery)`
- Call `uploadProfilePhoto` and show snackbar on success/error

## Files to modify

- `pyproject.toml` — add dependencies
- `backend/users/models.py` — add `profile_photo` field
- `backend/config/settings.py` — storage config
- `backend/config/urls.py` — dev media serving
- `backend/users/api.py` — photo upload/delete endpoints + schema update
- `.env.example` — B2 env vars
- `frontend/pubspec.yaml` — add `image_picker`
- `frontend/lib/models/user.dart` — add `profilePhotoUrl`
- `frontend/lib/providers/auth_provider.dart` — upload method
- `frontend/lib/screens/settings_screen.dart` — avatar UI

## Verification

1. `make lint` + `make frontend-lint`
2. Local dev: upload a photo → saved to `media/profile_photos/`, visible in settings
3. Set B2 env vars → upload goes to B2, URL returned is a B2 public URL
4. Photo shows in settings screen, persists across page refreshes
