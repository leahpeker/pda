# Recommendations Feature — Architecture & UX Exploration

> Issue #219: "explore different ways to create a recommendations store that people can add to for different locales — maybe connect this with a google maps list or something"

This document explores multiple architectural and UX directions for a community-driven recommendations feature. It also considers how an upcoming forum/messenger component might intersect.

---

## Current State

- **No tagging/categorization** beyond `EventType` (official / community) and `PageVisibility`
- **No user preferences or interests** are captured
- **No location-based features** beyond event lat/lng fields
- **Survey system** exists (flexible question types, JSON answers) — could be repurposed
- **Editable content pages** exist (rich text with Quill, slug-based, permission-gated)
- **13 permission keys** already defined — pattern for adding new ones is well-established
- **Navigation**: 3-tab bottom nav + logo menu for secondary pages; admin cards at `/admin`

---

## Option A: Structured Database — "Yelp-lite"

A first-class recommendation model with categories, ratings, and location data.

### Backend Models

```
Recommendation
  - id (UUID)
  - title, description
  - category (enum: restaurant, cafe, grocery, bakery, market, product, recipe, other)
  - locale / city / neighborhood (CharField or FK to Locale)
  - address, latitude, longitude
  - website_url, google_maps_url, instagram_url
  - photo (ImageField)
  - created_by (FK User)
  - visibility (public / members_only)
  - created_at, updated_at

RecommendationVote (optional)
  - recommendation (FK)
  - user (FK)
  - vote_type (upvote / heart / +1)
```

### UX
- Dedicated `/recommendations` route (public browse, members-only submit)
- Filter bar: category pills + locale dropdown + search
- Card grid layout with photo, name, category badge, vote count
- "add a rec" FAB for members
- Detail view with map embed, links, description, who recommended it

### Pros
- Clean, queryable, filterable data
- Easy to build top-10 lists, export, or surface in other contexts
- Familiar UX pattern (Yelp, HappyCow)

### Cons
- Most structured to build — full CRUD, model, schemas, provider, screen
- Could feel over-engineered for a small community
- Maintaining category taxonomy requires admin effort

### Forum interaction
- Forum threads could auto-link when a recommendation is mentioned
- "What's your favorite X?" forum threads could have a "pin as recommendation" action

---

## Option B: Curated Lists — "Google Maps Lists meets Notion"

Community-maintained lists organized by locale and theme, editable by members with permission.

### Backend Models

```
RecommendationList
  - id (UUID)
  - title (e.g., "NYC — restaurants", "LA — grocery stores")
  - slug
  - locale (CharField)
  - description
  - visibility
  - created_by (FK User)
  - editors (M2M User)  # collaborative editing

RecommendationItem
  - id (UUID)
  - list (FK RecommendationList)
  - name
  - note (short description / why it's good)
  - address
  - latitude, longitude
  - google_maps_url
  - website_url
  - added_by (FK User)
  - display_order
```

### UX
- `/recommendations` shows locale cards (NYC, LA, London…)
- Click a locale → see themed lists (restaurants, cafes, groceries, products…)
- Each list is a scrollable card list with items, optionally shown on a map
- Members can suggest items to any list; editors approve/curate
- Could embed a Google Maps iframe or link out to a shared Google Maps list

### Pros
- Naturally organized by locale — matches the issue description
- Collaborative editing gives ownership to local members
- Lists can be shared externally (public visibility)
- Lower friction than full Yelp-style structured data

### Cons
- Needs a curation/moderation layer (editors per list)
- Two-model hierarchy adds complexity
- Could diverge from Google Maps lists if both are maintained

### Forum interaction
- Each locale could have a paired forum channel for discussion
- List items could be surfaced as "pinned resources" in locale-specific forum channels

---

## Option C: Wiki-style Pages — "Editable Content Blocks per Locale"

Leverage the existing `EditablePage` system. Each locale gets a rich-text page that members collaboratively edit.

### Backend Changes
- Minimal: create new `EditablePage` records with slugs like `recs-nyc`, `recs-la`, `recs-london`
- Add a `RecommendationPage` model that wraps EditablePage with locale metadata
- Or: just use a convention — `EditablePage` with category = "recommendations" tag

### UX
- `/recommendations` lists locale pages
- Each page is a Quill rich-text document — members with permission can edit freely
- Content is freeform: headers for categories, bullet lists of places, embedded links
- Like a shared Google Doc per city

### Pros
- **Fastest to ship** — mostly reuses existing `EditableContentBlock` widget
- Maximum flexibility — community decides the format
- Familiar wiki/doc editing pattern
- Very low model complexity

### Cons
- No structured data — can't filter, sort, or show on a map
- No attribution (who added what) without version history
- Gets messy at scale — one person's formatting nightmare
- Hard to extract data for other features (forum integration, search)

### Forum interaction
- Forum threads per locale could serve as the "discussion" layer while the wiki page is the "canonical" layer
- Members discuss in forum, curators update the wiki

---

## Option D: Thread-based — "Recommendations as Forum Threads"

Recommendations live inside the forum system itself. Each locale is a forum channel; each recommendation is a thread.

### Architecture
- No separate recommendation model at all
- Forum channels: `#recs-nyc`, `#recs-la`, `#recs-london`
- Each thread = one recommendation (title = place name, body = details/review)
- Replies = other members' experiences, +1s, tips
- Threads can be tagged with categories (restaurant, grocery, etc.)
- Pinned threads = community favorites

### UX
- `/recommendations` is actually a filtered view of forum channels tagged as "recommendations"
- Users browse by locale (channel), then by category (tag filter)
- Adding a recommendation = starting a new thread with a structured template
- The thread template prompts for: name, category, address, why you like it
- Upvotes on the original post = endorsements

### Pros
- **Zero new models** if the forum system supports channels + tags + templates
- Naturally social — discussion and recommendations are one thing
- Recommendations feel alive (ongoing conversation) rather than static
- Reduces the "two places to post" problem
- Directly informs forum architecture decisions

### Cons
- Depends on forum system being built first (or simultaneously)
- Harder to extract structured data (address, map coordinates) from thread content
- Can get noisy — recommendations mixed with chatter
- No clean "list view" without a custom aggregation layer

### Forum architecture implications
This option suggests forums should support:
- **Channels** (locale-based grouping)
- **Thread templates** (structured first-post with fields)
- **Tags** (category filtering within channels)
- **Pinning** (curated highlights)
- **Upvotes/reactions** on posts

---

## Option E: Hybrid — "Structured Cards + Discussion Threads"

A dedicated recommendation model for the structured data, with each recommendation automatically linked to a forum thread for discussion.

### Architecture

```
Recommendation (structured)
  - title, category, locale, address, lat/lng, links, photo
  - created_by, visibility
  - forum_thread_id (FK to ForumThread, nullable)

ForumThread (from forum system)
  - auto-created when a recommendation is submitted
  - lives in the locale's #recs channel
  - replies = discussion, tips, counter-recs
```

### UX
- `/recommendations` shows the clean, filterable card grid (like Option A)
- Each card has a "discuss" button that opens the linked forum thread
- Forum channels for each locale show both recommendation threads and general discussion
- Submitting a recommendation creates both the structured record AND a thread

### Pros
- Best of both worlds: structured + social
- Clean browse/filter experience with organic discussion
- Recommendations stay discoverable even as forum threads scroll
- Natural bridge between the two features

### Cons
- Most complex — requires both recommendation and forum models
- Data synchronization between structured record and thread
- Two things to moderate

---

## Option F: Google Maps Integration — "External-first"

Lean into Google Maps Lists as the primary data store. The app links out to or embeds community-maintained Google Maps lists.

### Architecture (Minimal)

```
MapsList
  - id (UUID)
  - title ("NYC vegan spots", "LA grocery stores")
  - locale
  - google_maps_list_url
  - description
  - maintained_by (M2M User)
  - visibility
```

### Architecture (With sync)
- Use Google Maps Places API to pull list contents into the app
- Cache place details (name, address, rating, photos) locally
- Periodic sync or manual refresh

### UX (Minimal)
- `/recommendations` shows locale cards
- Each locale card links to curated Google Maps lists
- "Open in Google Maps" for each list
- Simple admin screen to manage list URLs

### UX (With embed)
- Embed Google Maps with list pins in the app via iframe or Flutter map widget
- Show place cards below the map
- "Add to list" redirects to Google Maps

### Pros
- **Easiest to maintain** — Google Maps is the source of truth
- Users get directions, reviews, photos for free
- No moderation burden — Maps handles it
- Very aligned with the issue description

### Cons
- Dependent on Google Maps Lists staying free/available
- Limited customization — can't add community-specific notes easily
- No in-app engagement (votes, discussion)
- Google Maps Lists are limited to 1 editor unless using My Maps
- Data lives outside the platform

### Forum interaction
- Forum channels per locale for discussion; Maps lists for reference
- Bot could post new list additions to the forum channel

---

## Option G: Tag + Collect from Activity — "Implicit Recommendations"

Instead of a dedicated recommendation flow, surface recommendations from existing activity: events at restaurants, RSVPs to food-related events, survey responses about favorite spots.

### Architecture
- Add a `tags` M2M field to Event model (or a separate Tag model)
- Add a `venue_type` field to Event (restaurant, park, community space, etc.)
- Build a "places" index from events that happened at specific venues
- Track which venues get repeat events / high RSVP counts
- Optional: let users "bookmark" or "heart" venues from past events

### UX
- `/recommendations` shows a map/list of venues where community events have happened
- Sorted by popularity (RSVP count, repeat events)
- Filter by venue type
- "Have you been here? Share your thoughts" links to forum thread

### Pros
- No new submission flow — recommendations emerge from existing behavior
- Authentic — these are places the community actually uses
- Low effort for users
- Encourages event creation at good spots

### Cons
- Only captures places where events happen, not general recommendations
- Requires tagging discipline on event creation
- Cold start problem — needs event history
- Doesn't capture product/grocery/recipe recommendations

---

## Cross-cutting Concerns

### Locale System
All options need some concept of locale. Options:
1. **Freeform string** — simplest, but inconsistent ("NYC" vs "New York" vs "new york")
2. **Predefined locale enum** — admin-managed list of active cities
3. **Google Places autocomplete** — structured city/neighborhood from Google API
4. **User-defined with normalization** — freeform input, admin can merge/rename

**Recommendation**: Start with a predefined locale list managed by admins (option 2). Add locales as the community expands. This matches the existing pattern of admin-managed content.

### Permission Model
- `manage_recommendations` permission for curating/moderating
- All members can submit; curators can edit/remove
- Public visibility for browse; member-only for submission

### Map Display
For any option with location data:
- **flutter_map** + OpenStreetMap tiles (free, no API key)
- **google_maps_flutter** (requires API key, better UX)
- **Link-out to Google Maps** (zero dependency, works everywhere)

### Search
- For structured options (A, B, E): standard text search on title/description + category filter
- For wiki/thread options (C, D): full-text search (harder)
- Could use the existing survey system to build a "what are you looking for?" flow

---

## Comparison Matrix

| Criterion | A: Yelp-lite | B: Curated Lists | C: Wiki Pages | D: Forum Threads | E: Hybrid | F: Google Maps | G: Implicit |
|-----------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| Build effort | High | Medium | Low | Medium* | High | Low | Medium |
| Structured data | ✅ | ✅ | ❌ | ⚠️ | ✅ | ⚠️ | ⚠️ |
| Community engagement | Low | Medium | Medium | High | High | Low | Low |
| Filterable/searchable | ✅ | ✅ | ❌ | ⚠️ | ✅ | ❌ | ✅ |
| Map integration | Easy | Easy | Hard | Hard | Easy | Built-in | Easy |
| Scales with community | ✅ | ✅ | ❌ | ⚠️ | ✅ | ✅ | ⚠️ |
| Forum synergy | Low | Medium | Medium | Native | High | Low | Medium |
| Matches issue vision | ✅ | ✅✅ | ⚠️ | ⚠️ | ✅✅ | ✅✅ | ❌ |
| Maintenance burden | Medium | Medium | Low | Low | High | Lowest | Low |

*Forum threads option requires forum system to exist first

---

## My Top-3 Recommendations (to narrow down)

1. **Option B (Curated Lists)** — Best balance of structure, locale-focus, and community ownership. Directly matches the issue vision. Can link out to Google Maps lists as a bridge.

2. **Option E (Hybrid)** if forums are coming soon — Gets the structured browse experience AND the social layer. More complex but future-proof.

3. **Option F (Google Maps)** as an MVP/Phase 0 — Ship a simple links page in days, validate that people actually want this, then build the real thing.

A phased approach could work: **F → B → E** (start with Google Maps links, build curated lists, add forum discussion threads when the forum ships).

---

## Forum Architecture Implications

Whichever recommendation option is chosen, the forum system should consider:

- **Channels/spaces** organized by topic or locale (not just one flat feed)
- **Thread templates** for structured posts (recommendation template, event discussion template)
- **Tags** for cross-cutting categorization
- **Pinning/bookmarking** for curated content
- **Reactions/upvotes** for lightweight endorsement
- **Rich embeds** — recommendation cards, event cards, map previews embedded in threads
- **Bot integrations** — auto-post when new recommendations are added, events created, etc.

The recommendations feature is a strong first use case to validate forum architecture decisions before building the general-purpose forum.
