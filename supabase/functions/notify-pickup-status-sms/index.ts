// Supabase Edge Function: notify-pickup-status-sms
//
// Fired by a Postgres trigger (trg_notify_customer_on_pickup_status_change,
// see supabase/migrations/20260824160000_pickup_status_sms_trigger.sql)
// whenever a pickup_requests row transitions to 'accepted' (rider accepts)
// or 'completed' (rider scans the bin QR code to confirm). Sends the
// customer an SMS via mNotify.
//
// Not user-facing (verify_jwt = false in config.toml) -- authenticated by a
// shared secret the trigger sends in x-webhook-secret, generated once and
// stored in both Supabase Vault (for the trigger) and this function's
// PICKUP_STATUS_SMS_WEBHOOK_SECRET secret. Never called directly by the app.
//
// SETUP: same mNotify credentials as notify-bin-assignment-sms -- admins can
// set them from the admin panel (Settings.jsx -> app_settings table, checked
// first below), or as a fallback for before that's configured:
//   supabase secrets set MNOTIFY_API_KEY="..."
//   supabase secrets set MNOTIFY_SENDER_ID="CleanConnect"   # optional, defaults below

import { createClient } from "@supabase/supabase-js";

interface PickupStatusPayload {
  requestId: string;
  customerId?: string;
  customerName?: string;
  phoneNumber: string;
  status: "accepted" | "completed" | string;
  riderName?: string;
  timeSlot?: string;
  location?: string;
  weightKg?: number;
}

const MNOTIFY_SENDER_ID_FALLBACK = "CleanConnect";

/** mNotify expects Ghanaian numbers as 233XXXXXXXXX (no leading '+' or '0'). */
function normalizePhoneNumber(raw: string): string {
  const digits = raw.replace(/[^0-9]/g, "");
  if (digits.startsWith("233")) return digits;
  if (digits.startsWith("0")) return `233${digits.slice(1)}`;
  return digits;
}

function buildMessage(payload: PickupStatusPayload): string {
  const greeting = payload.customerName ? `Hi ${payload.customerName}, ` : "Hi, ";

  if (payload.status === "accepted") {
    const rider = payload.riderName || "A CleanConnect rider";
    const slot = payload.timeSlot ? ` for your ${payload.timeSlot} slot` : "";
    return `${greeting}${rider} has accepted your pickup request${slot} and is on the way.`
      .replace(/\s+/g, " ")
      .trim();
  }

  if (payload.status === "completed") {
    const weight = payload.weightKg != null ? ` (${payload.weightKg}kg collected)` : "";
    return `${greeting}your pickup has been completed${weight}. Thank you for recycling with CleanConnect!`
      .replace(/\s+/g, " ")
      .trim();
  }

  return `${greeting}your CleanConnect pickup status changed to ${payload.status}.`
    .replace(/\s+/g, " ")
    .trim();
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const secret = req.headers.get("x-webhook-secret");
  if (!secret || secret !== Deno.env.get("PICKUP_STATUS_SMS_WEBHOOK_SECRET")) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  let payload: PickupStatusPayload;
  try {
    payload = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid request body." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (!payload.phoneNumber || !payload.status) {
    return new Response(
      JSON.stringify({ error: "phoneNumber and status are required." }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const { data: settings, error: settingsError } = await supabase
    .from("app_settings")
    .select("mnotify_api_key, mnotify_sender_id")
    .eq("id", true)
    .maybeSingle();
  if (settingsError) {
    console.warn("[notify-pickup-status-sms] app_settings lookup failed, falling back to secrets:", settingsError);
  }

  const apiKey = settings?.mnotify_api_key || Deno.env.get("MNOTIFY_API_KEY");
  if (!apiKey) {
    console.error("[notify-pickup-status-sms] No mNotify API key configured (app_settings or MNOTIFY_API_KEY).");
    return new Response(JSON.stringify({ error: "SMS provider is not configured." }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const senderId =
    settings?.mnotify_sender_id || Deno.env.get("MNOTIFY_SENDER_ID") || MNOTIFY_SENDER_ID_FALLBACK;
  const recipient = normalizePhoneNumber(payload.phoneNumber);
  const message = buildMessage(payload);

  try {
    const response = await fetch(
      `https://api.mnotify.com/api/sms/quick?key=${encodeURIComponent(apiKey)}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          recipient: [recipient],
          sender: senderId,
          message,
          is_schedule: false,
          schedule_date: "",
        }),
      },
    );

    const result = await response.json().catch(() => null);

    if (!response.ok) {
      console.error(
        `[notify-pickup-status-sms] mNotify request failed for request ${payload.requestId}:`,
        response.status,
        result,
      );
      return new Response(JSON.stringify({ error: "SMS provider request failed.", detail: result }), {
        status: 502,
        headers: { "Content-Type": "application/json" },
      });
    }

    console.log(`[notify-pickup-status-sms] sent for request ${payload.requestId} (${payload.status}) to ${recipient}.`);
    return new Response(JSON.stringify({ sent: true, result }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error(`[notify-pickup-status-sms] error sending SMS for request ${payload.requestId}:`, err);
    return new Response(JSON.stringify({ error: "Failed to send SMS." }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
