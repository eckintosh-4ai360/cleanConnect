// Supabase Edge Function: notify-bin-assignment-sms
//
// Fired by a Postgres trigger (trg_notify_customer_on_bin_assignment, see
// supabase/migrations/20260819180000_bin_assignment_sms_trigger.sql) whenever
// admin assigns/creates a company-owned bin for a customer. Sends the
// customer an SMS with their new bin's serial number via mNotify.
//
// Not user-facing (verify_jwt = false in config.toml) -- authenticated by a
// shared secret the trigger sends in x-webhook-secret, generated once and
// stored in both Supabase Vault (for the trigger) and this function's
// BIN_ASSIGNMENT_WEBHOOK_SECRET secret. Never called directly by the app.
//
// SETUP: the mNotify API key and sender ID are configurable two ways --
// admins can set them from the admin panel (Settings.jsx -> app_settings
// table, checked first below), or as a fallback for before that's configured:
//   supabase secrets set MNOTIFY_API_KEY="..."
//   supabase secrets set MNOTIFY_SENDER_ID="CleanConnect"   # optional, defaults below

import { createClient } from "@supabase/supabase-js";

interface BinAssignmentPayload {
  binId: string;
  customerId?: string;
  customerName?: string;
  phoneNumber: string;
  serialNumber: string;
  type?: string;
  size?: string;
}

const MNOTIFY_SENDER_ID_FALLBACK = "CleanConnect";

/** mNotify expects Ghanaian numbers as 233XXXXXXXXX (no leading '+' or '0'). */
function normalizePhoneNumber(raw: string): string {
  const digits = raw.replace(/[^0-9]/g, "");
  if (digits.startsWith("233")) return digits;
  if (digits.startsWith("0")) return `233${digits.slice(1)}`;
  return digits;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const secret = req.headers.get("x-webhook-secret");
  if (!secret || secret !== Deno.env.get("BIN_ASSIGNMENT_WEBHOOK_SECRET")) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  let payload: BinAssignmentPayload;
  try {
    payload = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid request body." }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (!payload.phoneNumber || !payload.serialNumber) {
    return new Response(
      JSON.stringify({ error: "phoneNumber and serialNumber are required." }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  // Admin-configured values in app_settings (Settings.jsx) win over the
  // MNOTIFY_API_KEY / MNOTIFY_SENDER_ID secrets, so admins can rotate the
  // key/sender ID from the panel without a CLI redeploy.
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
    console.warn("[notify-bin-assignment-sms] app_settings lookup failed, falling back to secrets:", settingsError);
  }

  const apiKey = settings?.mnotify_api_key || Deno.env.get("MNOTIFY_API_KEY");
  if (!apiKey) {
    console.error("[notify-bin-assignment-sms] No mNotify API key configured (app_settings or MNOTIFY_API_KEY).");
    return new Response(JSON.stringify({ error: "SMS provider is not configured." }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const senderId =
    settings?.mnotify_sender_id || Deno.env.get("MNOTIFY_SENDER_ID") || MNOTIFY_SENDER_ID_FALLBACK;
  const recipient = normalizePhoneNumber(payload.phoneNumber);
  const greeting = payload.customerName ? `Hi ${payload.customerName}, ` : "Hi, ";
  const message =
    `${greeting}your CleanConnect bin (${payload.type ?? "waste"} ${payload.size ?? ""}) ` +
    `has been assigned. Serial number: ${payload.serialNumber}.`.replace(/\s+/g, " ").trim();

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
        `[notify-bin-assignment-sms] mNotify request failed for bin ${payload.binId}:`,
        response.status,
        result,
      );
      return new Response(JSON.stringify({ error: "SMS provider request failed.", detail: result }), {
        status: 502,
        headers: { "Content-Type": "application/json" },
      });
    }

    console.log(`[notify-bin-assignment-sms] sent for bin ${payload.binId} to ${recipient}.`);
    return new Response(JSON.stringify({ sent: true, result }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error(`[notify-bin-assignment-sms] error sending SMS for bin ${payload.binId}:`, err);
    return new Response(JSON.stringify({ error: "Failed to send SMS." }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
