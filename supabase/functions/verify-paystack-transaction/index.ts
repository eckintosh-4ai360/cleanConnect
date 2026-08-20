// Supabase Edge Function: verify-paystack-transaction
//
// Called by the Flutter app right after the Paystack SDK checkout UI reports
// that a payment completed locally. The SDK's own result is not trustworthy
// on its own (it can resolve even when the plugin channel is broken, or be
// spoofed by a modified client), so this function re-checks the transaction
// against Paystack's own record before the app treats the payment as real.
//
// SETUP: uses the same PAYSTACK_SECRET_KEY secret as initialize-paystack-transaction.
//
// Expected request body:
//   { reference: string, expected_amount?: number, expected_currency?: string }
// Returns:
//   { verified: boolean, status: string, amount: number, currency: string, reference: string }

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
      { error: "You must be signed in to verify a payment." },
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
      { error: "You must be signed in to verify a payment." },
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

  const reference = body.reference;
  if (!reference || typeof reference !== "string") {
    return jsonResponse({ error: "A transaction reference is required." }, 400);
  }

  const expectedAmount =
    typeof body.expected_amount === "number" ? body.expected_amount : null;
  const expectedCurrency =
    typeof body.expected_currency === "string" ? body.expected_currency : null;

  const secretKey = Deno.env.get("PAYSTACK_SECRET_KEY");
  if (!secretKey) {
    console.error("[Paystack] PAYSTACK_SECRET_KEY secret is not set.");
    return jsonResponse({ error: "Payment service is not configured." }, 500);
  }

  // ── Call Paystack Verify Transaction API ─────────────────────────────────
  try {
    const paystackResponse = await fetch(
      `https://api.paystack.co/transaction/verify/${encodeURIComponent(reference)}`,
      {
        method: "GET",
        headers: { Authorization: `Bearer ${secretKey}` },
        signal: AbortSignal.timeout(15000),
      },
    );

    const paystackJson = await paystackResponse.json();
    const { status, data, message } = paystackJson ?? {};

    if (!status || !data) {
      console.error("[Paystack] Verify: unexpected API response:", paystackJson);
      return jsonResponse(
        { verified: false, error: message || "Could not verify transaction." },
        502,
      );
    }

    const chargeSucceeded = data.status === "success";
    const amountMatches = expectedAmount === null || data.amount === expectedAmount;
    const currencyMatches =
      expectedCurrency === null || data.currency === expectedCurrency;

    const verified = chargeSucceeded && amountMatches && currencyMatches;

    if (!verified) {
      console.warn(
        `[Paystack] Verify: reference ${reference} not accepted — ` +
          `status=${data.status} amount=${data.amount} currency=${data.currency} uid=${user.id}`,
      );
    } else {
      console.log(`[Paystack] Verify: reference ${reference} confirmed — uid: ${user.id}`);
    }

    return jsonResponse({
      verified,
      status: data.status,
      amount: data.amount,
      currency: data.currency,
      reference: data.reference,
    });
  } catch (err) {
    console.error("[Paystack] Verify API error:", err);
    return jsonResponse(
      { verified: false, error: "Could not reach payment service. Please try again." },
      500,
    );
  }
});
