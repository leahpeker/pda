# Live Notifications Plan — Issue #222

> "hookup notifications to webhook so that notifications are live — explore how this is different if we switch to mobile app"

---

## Current State

**What exists:**
- `Notification` model with one type (`EVENT_INVITE`) — `backend/notifications/models.py`
- REST endpoints: list, unread count, mark read, mark all read — `backend/notifications/api.py`
- Service layer: `create_event_invite_notifications()` bulk-creates DB records — `backend/notifications/service.py`
- WhatsApp group broadcast via external bot service — `backend/notifications/whatsapp.py`
- Flutter `NotificationBell` widget with badge + bottom sheet — `frontend/lib/widgets/notification_bell.dart`
- `unreadCountProvider` polls `GET /notifications/unread-count/` every 60s — `frontend/lib/providers/notification_provider.dart`
- Tab visibility awareness — skips polls when browser tab is hidden

**What's missing:**
- No real-time delivery (WebSocket, SSE, or push)
- No ASGI server (runs Gunicorn WSGI)
- No Redis or any channel layer
- No Firebase / FCM / service worker
- No Celery or task queue
- No notification preferences (opt-in/out)
- Only one notification type (event invites)

**Infrastructure:** Django 6.0 + Django Ninja, Gunicorn WSGI, Railway deployment, PostgreSQL, WhiteNoise static files, Flutter web SPA served from same origin.

---

## Options for Live Notifications

### Option 1: Server-Sent Events (SSE)

**How it works:** The client opens a long-lived HTTP connection. The server pushes events down the stream as they occur. One-directional (server → client only).

#### Backend
- Add an SSE endpoint: `GET /api/notifications/stream/` that holds the connection open
- Use Django's `StreamingHttpResponse` with an async generator
- Requires switching to **ASGI** (Uvicorn or Daphne) to support async streaming
- Need a pub/sub mechanism to notify the SSE handler when new notifications are created:
  - **Option 1a: PostgreSQL LISTEN/NOTIFY** — zero new infrastructure, Postgres-native
  - **Option 1b: Redis pub/sub** — standard but adds a service
  - **Option 1c: In-process queue** — only works with single-process deployment

#### Frontend
- Replace the 60s polling loop with an `EventSource` / SSE client
- On receiving an event, invalidate `unreadCountProvider` and `notificationsProvider`
- Reconnect on disconnect with exponential backoff
- No new packages needed — `dart:html` has `EventSource` for web

#### Railway deployment
- Railway supports long-lived HTTP connections (SSE works)
- Must switch Dockerfile CMD from `gunicorn config.wsgi` to `uvicorn config.asgi:application`
- WhiteNoise needs ASGI-compatible mode or switch to Django's `ASGIStaticFilesHandler`

#### Pros
- **Simplest real-time option** — no WebSocket protocol, no Redis required (with PG LISTEN/NOTIFY)
- Works over standard HTTP — no proxy/firewall issues
- Lighter than WebSockets for notification-only use case (server → client)
- Browser-native `EventSource` with automatic reconnection
- No new Python packages needed beyond Django's async support

#### Cons
- **Requires ASGI migration** — Gunicorn → Uvicorn, `wsgi.py` → `asgi.py`
- One-directional — can't use for future chat/forum real-time features
- Each connected client holds a server connection open (memory/connection pool concern at scale)
- PostgreSQL LISTEN/NOTIFY doesn't persist messages if client disconnects (must fall back to REST fetch on reconnect)
- Not supported in all contexts on mobile (would need a different solution for native app)

#### Effort: Medium

---

### Option 2: WebSockets (Django Channels)

**How it works:** Full-duplex persistent connection between client and server. Both sides can send messages at any time.

#### Backend
- Add `channels` and `channels-redis` to dependencies
- Create `notifications/consumers.py` with a `NotificationConsumer` (async WebSocket consumer)
- Create `notifications/routing.py` mapping `ws/notifications/` to the consumer
- Switch to ASGI: `config/asgi.py` with `ProtocolTypeRouter` for HTTP + WebSocket
- Add JWT auth middleware for WebSocket connections (token in query string or first message)
- When `create_event_invite_notifications()` runs, also push to the user's WebSocket channel group
- **Requires Redis** as the channel layer backend

#### Frontend
- Add `web_socket_channel` package to pubspec.yaml
- Create a `WebSocketProvider` that manages connection lifecycle (connect, reconnect, auth)
- On receiving a message, update notification state reactively
- Handle reconnection with backoff on network changes

#### Railway deployment
- Add a **Redis service** on Railway (~$5/mo)
- Switch to Uvicorn/Daphne for ASGI
- Railway supports WebSocket connections

#### Pros
- **Full-duplex** — reusable for future forum/messenger real-time features
- Industry standard for real-time web apps
- Django Channels is mature, well-documented
- Channel groups make per-user and broadcast messaging easy
- One investment serves notifications, chat, live updates, typing indicators, etc.

#### Cons
- **Highest complexity** — new dependency (Channels), new infrastructure (Redis), ASGI migration
- Redis adds cost and operational burden
- WebSocket auth is more complex than REST (no cookies, need token handshake)
- Overkill if notifications are the only real-time feature
- Connection management on the frontend is non-trivial (reconnect, auth refresh)

#### Effort: High

---

### Option 3: Webhook + Push Notifications (Web Push / FCM)

**How it works:** Server sends push notifications via a push service (Firebase Cloud Messaging or Web Push API). The browser/device receives them even when the app isn't open.

#### Backend
- Add `pywebpush` or `firebase-admin` to dependencies
- Create a `PushSubscription` model to store per-device push tokens
- Add endpoints: `POST /api/notifications/subscribe/` and `DELETE /api/notifications/unsubscribe/`
- When creating notifications, also send a push via the push service
- Need a VAPID key pair (Web Push) or Firebase project (FCM)

#### Frontend (Web)
- Register a **service worker** (`firebase-messaging-sw.js` or custom SW)
- Request notification permission from the user
- On permission grant, get push subscription and POST to backend
- Service worker handles incoming push events and shows browser notifications
- Clicking the notification opens/focuses the app

#### Frontend (Mobile — future)
- Firebase Messaging for Android/iOS
- `firebase_core` + `firebase_messaging` packages
- Platform-specific setup (APNs cert for iOS, google-services.json for Android)
- Background message handling

#### Railway deployment
- No special infrastructure needed (push service is external)
- Can stay on WSGI/Gunicorn — no ASGI migration required
- May want Celery for async push sending to avoid blocking requests

#### Pros
- **No ASGI migration needed** — works with existing Gunicorn WSGI setup
- **Works when app is closed** — true push notifications
- **Best mobile experience** — native push is the expected mobile pattern
- No persistent connections to manage
- FCM is free for reasonable volumes
- Most natural path if mobile app is planned

#### Cons
- **Browser notification UX is mediocre** — users must grant permission, many decline
- Requires Firebase project setup and management
- Service worker complexity in Flutter web build pipeline
- Push tokens expire and must be refreshed
- No real-time in-app updates — still need polling or SSE for live badge updates while app is open
- Two systems: push for background + polling for foreground

#### Effort: Medium

---

### Option 4: Short Polling (Improve Current System)

**How it works:** Keep the existing polling approach but make it faster and smarter.

#### Changes
- Reduce poll interval from 60s to 10-15s
- Add ETag/If-Modified-Since headers to avoid transferring data when nothing changed
- Backend returns 304 Not Modified when no new notifications
- Add a lightweight `GET /notifications/poll/` endpoint that returns only `{count, latest_id}` (minimal payload)
- Frontend shows a toast/snackbar when count increases between polls

#### Pros
- **Zero infrastructure changes** — no ASGI, no Redis, no Firebase
- **Trivial to implement** — a few hours of work
- Works identically on web and mobile
- No new dependencies
- Easy to reason about and debug

#### Cons
- **Not truly real-time** — 10-15s delay at best
- Wastes bandwidth and server resources with empty polls
- Doesn't scale well with many concurrent users
- No background notifications (app must be open)
- "Webhook" in the issue title suggests the user wants something more

#### Effort: Low

---

### Option 5: Hybrid — SSE for Web + Push for Mobile

**How it works:** Use SSE for real-time in-app updates on web, and FCM push for the eventual mobile app. Share the same notification creation pipeline.

#### Architecture
```
Notification created (DB)
  ├── SSE: push event to connected web clients (PG LISTEN/NOTIFY)
  ├── Push: send FCM notification to mobile devices
  └── WhatsApp: broadcast to group (existing)
```

#### Backend
- ASGI migration for SSE support
- SSE endpoint with PG LISTEN/NOTIFY
- `PushSubscription` model + FCM integration (added when mobile ships)
- Notification service dispatches to all channels

#### Frontend (Web — now)
- SSE client replaces polling
- In-app badge + toast updates in real-time

#### Frontend (Mobile — later)
- Firebase Messaging for native push
- SSE or WebSocket for in-app real-time (if needed)

#### Pros
- **Right tool for each platform** — SSE is ideal for web, push is ideal for mobile
- SSE requires no Redis (with PG LISTEN/NOTIFY)
- Push notifications can be added incrementally when mobile ships
- Clean separation of concerns

#### Cons
- Two delivery mechanisms to maintain
- Still requires ASGI migration for SSE
- More code paths to test

#### Effort: Medium (SSE now) + Medium (push later)

---

## Web vs. Mobile App — How It Changes

| Aspect | Flutter Web (current) | Mobile App (future) |
|--------|----------------------|-------------------|
| **Background notifications** | Only via Web Push API / service worker | Native push via FCM/APNs — expected and reliable |
| **Persistent connections** | SSE/WebSocket work well, but killed when tab closes | Can maintain background connections, but OS may kill them |
| **User expectation** | Badge + in-app updates are sufficient | Push notifications are table stakes — users expect them |
| **Permission model** | Browser notification permission (many users decline) | OS notification permission (most users accept) |
| **Service worker** | Required for Web Push, complex in Flutter web | Not needed — native push handles it |
| **Best real-time approach** | SSE or WebSocket for in-app; Web Push optional | FCM push for background; WebSocket/SSE for in-app |
| **Offline support** | Limited — web apps lose state | Can queue notifications, show them on reconnect |

**Key insight:** If a mobile app is planned, investing in FCM now pays off later. If staying web-only for the foreseeable future, SSE is simpler and avoids Firebase complexity.

---

## Recommendation

### If staying web-only (near-term): **Option 1 — SSE with PG LISTEN/NOTIFY**

- Minimal new infrastructure (no Redis, no Firebase)
- Genuine real-time for in-app updates
- Requires ASGI migration, but that's a one-time investment that benefits future features (forums, live updates)
- PG LISTEN/NOTIFY is free — uses existing PostgreSQL

### If mobile app is planned (6-12 months): **Option 5 — Hybrid (SSE + Push)**

- SSE for web now, FCM push when mobile ships
- ASGI migration still needed, but it's the right foundation
- Defers Firebase complexity until it's actually needed

### If you want something shipped this week: **Option 4 — Improved Polling**

- Reduce interval to 15s, add ETag caching, add toast on new notifications
- Zero infrastructure risk, can be done in a few hours
- Good stopgap while planning the real solution

### NOT recommended: **Option 2 (WebSockets)** unless forums/messenger are imminent

- Redis cost + complexity isn't justified for notifications alone
- If forums are 3+ months away, SSE covers the gap
- When forums ship, *then* migrate SSE → WebSockets with Redis

---

## Implementation Outline (for recommended SSE approach)

### Phase 1: ASGI Migration
1. Create `config/asgi.py` with Django's `get_asgi_application()`
2. Switch Dockerfile CMD: `gunicorn` → `uvicorn config.asgi:application --host 0.0.0.0 --port $PORT`
3. Update WhiteNoise config for ASGI compatibility
4. Add `uvicorn` to pyproject.toml
5. Test that all existing endpoints still work
6. Deploy and verify on Railway

**Files:** `config/asgi.py`, `Dockerfile`, `pyproject.toml`, `config/settings.py`

### Phase 2: SSE Endpoint + PG LISTEN/NOTIFY
1. Add a `notify_user(user_id)` function that calls `pg_notify('notifications', user_id)`
2. Call `notify_user()` from `create_event_invite_notifications()` in `service.py`
3. Add SSE endpoint `GET /api/notifications/stream/` that:
   - Authenticates via JWT (query param or header)
   - Opens a PG LISTEN on `'notifications'`
   - Filters for the authenticated user's ID
   - Yields SSE events with `{type, count}` payload
   - Sends heartbeat pings every 30s to keep connection alive
4. Add reconnection and error handling

**Files:** `notifications/api.py`, `notifications/service.py`, new `notifications/sse.py`

### Phase 3: Frontend SSE Client
1. Create `services/notification_stream.dart` — SSE client using `dart:html` `EventSource`
2. Create `providers/notification_stream_provider.dart` — Riverpod provider managing the SSE connection
3. On SSE event received: invalidate `unreadCountProvider` and `notificationsProvider`
4. On disconnect: reconnect with exponential backoff, fall back to polling
5. Remove or reduce the 60s polling loop (keep as fallback only)
6. Add a toast/snackbar when new notification arrives

**Files:** `frontend/lib/services/notification_stream.dart`, `frontend/lib/providers/notification_provider.dart`, `frontend/lib/providers/notification_stream_provider.dart`

### Phase 4: Verification
- Create a test event invite → verify notification appears in real-time (no page refresh)
- Close and reopen tab → verify reconnection and state sync
- Test with multiple users simultaneously
- Verify Railway deployment with long-lived SSE connections
- Run `make ci` to confirm nothing is broken

---

## Future: Adding Push Notifications (when mobile ships)

1. Create Firebase project, add `firebase-admin` to backend
2. Add `PushSubscription` model (user, device_token, platform, created_at)
3. Add subscribe/unsubscribe endpoints
4. In notification service: dispatch to SSE *and* FCM
5. Frontend: add `firebase_core` + `firebase_messaging` to pubspec.yaml
6. Mobile: request permission, register token, handle background messages
7. Web: optionally add Web Push via service worker (or keep SSE-only for web)
