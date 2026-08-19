# Push Notifications — Setup & Status

Riders get an "incoming pickup request" alert (full-screen intent, sound,
looping vibration) when a customer creates a pending pickup. The path is:

```
customer INSERT on pickup_requests
  -> trg_notify_riders_on_new_pickup (Postgres trigger, pg_net)
  -> notify-riders-on-new-pickup (Supabase Edge Function)
  -> FCM v1 data message to every riders.fcm_token
  -> NotificationService / firebaseMessagingBackgroundHandler (Flutter)
```

Data-only messages (no `notification` block) on purpose — that is what lets the
app take over rendering and vibration even when it is backgrounded or killed.

## Done in the repo

- `lib/core/services/notification_service.dart` — permissions, channel, token
  sync, foreground/background/terminated handling, tap -> navigation.
- `lib/firebase_options.dart` + the `com.google.gms.google-services` Gradle
  plugin — Firebase actually initializes on Android now.
- `AndroidManifest.xml` — `POST_NOTIFICATIONS`, `USE_FULL_SCREEN_INTENT`,
  `VIBRATE`, `WAKE_LOCK`.
- `supabase/migrations/20260818112801_enable_pg_net.sql`,
  `20260818113212_notify_riders_trigger.sql`,
  `20260819120000_pickup_webhook_secret.sql`.
- `supabase/functions/notify-riders-on-new-pickup/`.

## Backend status — verified 2026-08-19

All server-side setup is done and checked against the live project
(`mfysompctaxldphbxvkv`):

| Check | Result |
| --- | --- |
| `pg_net` extension | installed |
| `trg_notify_riders_on_new_pickup` trigger | present |
| Vault `pickup_webhook_secret` | present, SHA-256 matches `PICKUP_WEBHOOK_SECRET` |
| `PICKUP_WEBHOOK_SECRET` (function env) | set |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | set |
| Service account -> Google OAuth | mints an access token |
| Service account -> FCM v1 `messages:send` | reachable; rejects only a fake device token |
| Edge function deployed | ACTIVE, `verify_jwt=false`; returns 401 to a wrong secret |
| `riders.fcm_token` populated | **0 of 1 riders** |

The last row is the only outstanding item, and it can only be fixed from a
real device — see below.

Useful: `supabase db query` needs `--linked`, or it tries local Docker. The
CLI is not on PATH here; use `npx supabase`.

## Remaining step: register a device token

No rider has ever registered an FCM token, because until the Gradle fix the
app could not initialize Firebase at all. Push cannot be delivered to anyone
until this is done.

Requires a **physical Android device** (or an emulator with a Google Play
system image — plain AVDs have no Play services and never receive a token):

```bash
flutter install          # build/app/outputs/flutter-apk/app-debug.apk
```

Sign in as a rider, accept the notification permission prompt, then confirm:

```bash
npx supabase db query --linked   "select count(*) from riders where fcm_token is not null;"
```

Once that returns 1 or more, create a pickup request from a customer account.
Watch the Edge Function logs in the dashboard (this CLI version has no
`functions logs`): `sent: 1` means delivered.

## iOS (only if you ship iOS)

Currently unconfigured — `DefaultFirebaseOptions.currentPlatform` throws on
iOS/macOS and `main()` logs `PUSH DISABLED` and carries on.

1. Firebase Console -> add an iOS app with bundle id `com.ecowaste.cleanconnect.clean_connect`.
2. Download `GoogleService-Info.plist`, add it to `ios/Runner` **through Xcode**
   (it must be in the Runner target's Copy Bundle Resources).
3. Apple Developer -> Keys -> create an **APNs Auth Key** (.p8); upload it under
   Firebase Project Settings -> Cloud Messaging.
4. In Xcode, enable the **Push Notifications** and **Background Modes ->
   Remote notifications** capabilities.
5. Fill in the `ios` block in `lib/firebase_options.dart` and add the
   `TargetPlatform.iOS` case to `currentPlatform`.

Note: iOS suppresses the Android-style full-screen-intent behaviour — a
data-only message can only wake the app for a normal banner there.

## Web (optional)

`web/` has no `firebase-messaging-sw.js`, so web push does not work. It needs
that service worker plus a VAPID key passed to `getToken(vapidKey: ...)`.
Riders are mobile-only today, so this is not wired up.

## Verifying

1. Sign in as a rider on a physical Android device, accept the notification
   permission prompt. Confirm a token landed:
   `select id, fcm_token_updated_at from riders where fcm_token is not null;`
2. Create a pickup request from a customer account.
3. `supabase functions logs notify-riders-on-new-pickup` should show
   `sent: <n>`.
4. Background the rider app, then fully kill it, and repeat — the alert should
   fire in all three states.

If nothing arrives, check the Flutter log for a line starting `!! PUSH
DISABLED` — that means Firebase never initialized on the device, which is a
client-side config problem, not a server one.
