// Supabase Edge Function: notify-riders-on-new-pickup
//
// Fired by a Postgres trigger (trg_notify_riders_on_new_pickup, see
// supabase/migrations/20260818113212_notify_riders_trigger.sql) whenever a
// customer creates a new pending pickup request. Broadcasts a data-only FCM
// push to every rider with a stored fcm_token, so the app can show an
// on-screen "incoming request" alert with vibration — even in the background
// or when the app is killed (Android). Ports functions/index.js's
// notifyRidersOnNewPickup Cloud Function.
//
// Not user-facing (verify_jwt = false in config.toml) — authenticated by a
// shared secret the trigger sends in x-webhook-secret, generated once and
// stored in both Supabase Vault (for the trigger) and this function's
// PICKUP_WEBHOOK_SECRET secret. Never called directly by the Flutter app.
//
// SETUP: store the Firebase service account JSON (Firebase Console -> Project
// Settings -> Service Accounts -> Generate new private key) via:
//   supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON="$(cat service-account.json)"

import { createClient } from "@supabase/supabase-js";
import { GoogleAuth } from "google-auth-library";

interface PickupPayload {
  requestId: string;
  customerId?: string;
  customerName?: string;
  location?: string;
  timeSlot?: string;
  binTypes?: string[];
}

let cachedAuth: GoogleAuth | null = null;
function getGoogleAuth(): GoogleAuth {
  if (cachedAuth) return cachedAuth;
  const credentials = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON")!);
  cachedAuth = new GoogleAuth({
    credentials,
    scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
  });
  return cachedAuth;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const secret = req.headers.get("x-webhook-secret");
  if (!secret || secret !== Deno.env.get("PICKUP_WEBHOOK_SECRET")) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  let payload: PickupPayload;
  try {
    payload = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid request body." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: riders, error: ridersError } = await supabase
    .from("riders")
    .select("fcm_token")
    .not("fcm_token", "is", null);

  if (ridersError) {
    console.error("[notify-riders] failed to load rider tokens:", ridersError);
    return new Response(JSON.stringify({ error: "Failed to load rider tokens." }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const tokens = (riders ?? [])
    .map((r) => r.fcm_token as string | null)
    .filter((t): t is string => !!t && t.length > 0);

  if (tokens.length === 0) {
    console.log(`[notify-riders] no rider tokens found for request ${payload.requestId}.`);
    return new Response(JSON.stringify({ sent: 0 }), {
      headers: { "Content-Type": "application/json" },
    });
  }

  let accessToken: string | null | undefined;
  let projectId: string;
  try {
    const auth = getGoogleAuth();
    const client = await auth.getClient();
    accessToken = (await client.getAccessToken()).token;
    projectId = (await auth.getProjectId()) as string;
  } catch (err) {
    console.error("[notify-riders] Firebase service account not configured correctly:", err);
    return new Response(JSON.stringify({ error: "Push service is not configured." }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const data = {
    type: "new_pickup_request",
    requestId: payload.requestId ?? "",
    customerId: payload.customerId ?? "",
    customerName: payload.customerName ?? "Customer",
    location: payload.location ?? "",
    timeSlot: payload.timeSlot ?? "",
    binTypes: JSON.stringify(payload.binTypes ?? []),
  };

  const results = await Promise.allSettled(
    tokens.map((token) =>
      fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token,
            data,
            android: { priority: "high" },
            apns: {
              headers: { "apns-priority": "10" },
              payload: { aps: { "content-available": 1 } },
            },
          },
        }),
      })
    ),
  );

  const successCount = results.filter(
    (r) => r.status === "fulfilled" && r.value.ok,
  ).length;
  const failureCount = results.length - successCount;

  console.log(
    `[notify-riders] request ${payload.requestId}: sent to ${tokens.length} riders, ` +
      `success=${successCount}, failure=${failureCount}`,
  );

  return new Response(JSON.stringify({ sent: successCount, failed: failureCount }), {
    headers: { "Content-Type": "application/json" },
  });
});
