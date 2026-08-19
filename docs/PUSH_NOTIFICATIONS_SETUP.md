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

## Remaining console steps

### 1. Apply migrations and read the webhook secret

```bash
supabase db push
```

Then, in the SQL editor (or `supabase db execute`):

```sql
select decrypted_secret from vault.decrypted_secrets
 where name = 'pickup_webhook_secret';
```

### 2. Firebase service account for FCM v1

Firebase Console -> Project Settings -> Service Accounts -> **Generate new
private key**. Save the JSON somewhere outside the repo.

### 3. Set the Edge Function secrets and deploy

```bash
supabase secrets set PICKUP_WEBHOOK_SECRET="<value from step 1>"
supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON="$(cat /path/to/service-account.json)"
supabase functions deploy notify-riders-on-new-pickup
```

Both secrets are required: a missing `PICKUP_WEBHOOK_SECRET` makes every call
401, and a missing service account makes the function 500 with
"Push service is not configured."

### 4. iOS (only if you ship iOS)

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

### 5. Web (optional)

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
