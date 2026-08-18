# Google Maps setup

The app ships with real Google Maps wired into four surfaces. None of them
render until you supply API keys — everything below is the one-time setup.

Until keys are added the app still runs: maps show a grey tile, and route/ETA
figures fall back to straight-line geometry (clearly labelled as such in the
UI). Nothing crashes and no screen is blocked.

---

## 1. Create the keys in Google Cloud Console

Create a project, **enable billing** (Maps Platform requires a billing account
even inside the free monthly credit), then enable these APIs:

| API | Needed for |
|---|---|
| **Maps SDK for Android** | Rider navigation + route map on Android |
| **Maps SDK for iOS** | Same screens on iOS |
| **Maps JavaScript API** | Flutter web build, and the admin panel fleet map |
| **Routes API** | Road-following polylines, turn-by-turn text, traffic ETAs |
| **Geocoding API** | Resolving legacy pickup rows that stored a plain address |

Then create **four separate keys**, each restricted. One key for everything
works but means a leak anywhere compromises every platform.

| Key | Restriction | Used by |
|---|---|---|
| Android key | Android apps → package `com.ecowaste.cleanconnect.clean_connect` + your SHA-1 | `android/local.properties` |
| iOS key | iOS apps → bundle ID | `ios/Runner/Info.plist` |
| Browser key | HTTP referrers → your domains + `localhost` | `web/index.html`, `admin_panel/.env.local` |
| Web-service key | IP addresses, or none + tight quotas | `--dart-define=MAPS_WEB_API_KEY` |

Get your debug SHA-1 with:

```bash
keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android -keypass android
```

---

## 2. Android

Add to `android/local.properties` (git-ignored — never commit a key):

```properties
MAPS_API_KEY=AIza...your-android-key
```

`android/app/build.gradle.kts` reads it and injects it into the manifest via
`manifestPlaceholders`, so no key is ever checked in.

Location permissions (`ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`,
`FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`) are already declared in
`AndroidManifest.xml`.

---

## 3. iOS

Open `ios/Runner/Info.plist` and fill in the empty `GMSApiKey` string:

```xml
<key>GMSApiKey</key>
<string>AIza...your-ios-key</string>
```

`AppDelegate.swift` reads it at launch and hands it to `GMSServices`.

An iOS Maps key always ships inside the app binary — that is unavoidable and
true of every iOS Maps app. The bundle-ID restriction in Cloud Console is the
actual security boundary, not secrecy.

The `NSLocation*UsageDescription` strings and the `location` background mode
are already in the plist. Edit the copy in `Info.plist` if you want different
wording in the permission prompts — the text users see comes from there.

---

## 4. Flutter web

In `web/index.html`, replace `YOUR_BROWSER_MAPS_API_KEY`:

```html
<script src="https://maps.googleapis.com/maps/api/js?key=AIza...&loading=async&libraries=geometry"></script>
```

---

## 5. Routes / Geocoding (the web-service key)

This one is **not** in a manifest — it is passed at build time and read by Dart
in `lib/core/config/map_config.dart`:

```bash
flutter run --dart-define=MAPS_WEB_API_KEY=AIza...your-web-service-key
flutter build apk --dart-define=MAPS_WEB_API_KEY=AIza...
```

To avoid retyping it, put it in `.vscode/launch.json` under `toolArgs`, or use
a `--dart-define-from-file=env.json`.

**Without this key everything still works**, degraded predictably:

- Route lines become straight point-to-point instead of following roads, drawn
  **dashed** to signal the difference.
- ETAs come from a 22 km/h urban average rather than live traffic, and the UI
  labels them "Direct-line estimate".
- Turn-by-turn instructions are unavailable; the banner shows a heading prompt.
- Legacy pickups stored as a plain address cannot be geocoded, and the map says
  so instead of guessing.

---

## 6. Admin panel

```bash
cd admin_panel
cp .env.example .env.local
```

Fill in `VITE_GOOGLE_MAPS_API_KEY` with the **browser** key. Optionally set
`VITE_GOOGLE_MAPS_MAP_ID` to a Map ID created in Cloud Console — without one the
map uses `DEMO_MAP_ID`, which works but carries a development watermark.

Restart the dev server after editing (`.env` files are read at startup only).

---

## 7. Database migration

The tracking features need one migration applied:

```bash
supabase db push
```

`supabase/migrations/20260818131500_pickup_destination_coordinates.sql` adds
`pickup_requests.location_lat/location_lng`, backfills them from any existing
`location` text that already held coordinates, and adds two RPCs
(`set_pickup_destination`, `get_pickup_rider_card`).

---

## Cost control

Set a **budget alert** and per-API **quota caps** in Cloud Console before going
live. The app already limits its own spend:

- Rider location writes are throttled to one per 5 s (`MapConfig.riderUploadInterval`).
- A new route is only requested after the rider drifts 120 m from the last one
  (`MapConfig.routeRefreshThresholdMeters`).
- Identical origin/destination pairs are served from an in-memory cache in
  `DirectionsService`.
- Destination coordinates are captured once at booking time and stored, so the
  Geocoding API is only touched for legacy rows.

---

## Verifying it works

1. Apply the migration and set at least the Android key.
2. Sign in as a customer, book a pickup, and confirm the dashboard shows the
   **"Finding you a rider"** banner.
3. Sign in as a rider on a second device, accept the pickup, and open
   **Navigation**. Walk or drive — the marker should move with you and the
   "Live • sharing with dispatch" chip should be green.
4. Back on the customer device, tap the banner. The rider marker should move
   within a few seconds of the rider's device moving.
5. Open the admin panel → **Fleet Map**. The same rider should be plotted and
   moving.

If the map is grey: the key is missing, the wrong API is enabled, or the
restriction does not match. Check `adb logcat | grep -i "Google Maps"` on
Android or the browser console on web — Google logs a specific reason.
