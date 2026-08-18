// Supabase Edge Function: initialize-paystack-transaction
//
// Called by the Flutter app to initialize a Paystack transaction and receive
// an access_code. The Flutter SDK then uses this access_code to launch the
// Paystack payment UI. Ports functions/index.js's initializePaystackTransaction
// Cloud Function 1:1 — see the plan at .claude/plans (Phase 2).
//
// SETUP: store the Paystack secret key via the Supabase CLI:
//   supabase secrets set PAYSTACK_SECRET_KEY=sk_test_...
//
// Expected request body:
//   { email: string, amount: number (smallest unit), currency?: string, metadata?: object }
// Returns:
//   { access_code: string, reference: string, authorization_url: string }

import { createClient } from "@supabase/supabase-js";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // ── Auth check ────────────────────────────────────────────────────────────
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse(
      { error: "You must be signed in to make a payment." },
      401,
    );
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser();

  if (authError || !user) {
    return jsonResponse(
      { error: "You must be signed in to make a payment." },
      401,
    );
  }

  // ── Input validation ─────────────────────────────────────────────────────
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid request body." }, 400);
  }

  const email = body.email;
  const amount = body.amount;
  const currency = typeof body.currency === "string" ? body.currency : "GHS";
  const metadata =
    typeof body.metadata === "object" && body.metadata !== null
      ? (body.metadata as Record<string, unknown>)
      : {};

  if (!email || typeof email !== "string") {
    return jsonResponse({ error: "A valid email address is required." }, 400);
  }
  if (!amount || typeof amount !== "number" || amount <= 0) {
    return jsonResponse(
      { error: "Amount must be a positive number (in smallest currency unit)." },
      400,
    );
  }

  const secretKey = Deno.env.get("PAYSTACK_SECRET_KEY");
  if (!secretKey) {
    console.error("[Paystack] PAYSTACK_SECRET_KEY secret is not set.");
    return jsonResponse({ error: "Payment service is not configured." }, 500);
  }

  // ── Call Paystack Initialize Transaction API ─────────────────────────────
  try {
    const paystackResponse = await fetch(
      "https://api.paystack.co/transaction/initialize",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${secretKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          email,
          amount,
          currency,
          metadata: { ...metadata, user_uid: user.id },
        }),
        signal: AbortSignal.timeout(15000),
      },
    );

    const paystackJson = await paystackResponse.json();
    const { status, data, message } = paystackJson ?? {};

    if (!status || !data?.access_code) {
      console.error("[Paystack] Unexpected API response:", paystackJson);
      return jsonResponse(
        { error: message || "Failed to initialize payment." },
        502,
      );
    }

    console.log(
      `[Paystack] Transaction initialized — reference: ${data.reference}, uid: ${user.id}`,
    );

    return jsonResponse({
      access_code: data.access_code,
      reference: data.reference,
      authorization_url: data.authorization_url,
    });
  } catch (err) {
    console.error("[Paystack] API error:", err);
    return jsonResponse(
      { error: "Could not reach payment service. Please try again." },
      500,
    );
  }
});
