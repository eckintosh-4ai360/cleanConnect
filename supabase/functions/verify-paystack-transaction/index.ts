// Supabase Edge Function: verify-paystack-transaction
//
// Called by the Flutter app once the hosted Paystack checkout page redirects to
// the callback URL. That redirect is not trustworthy on its own (it can be
// reached by a modified client, or the customer can close the sheet mid-flow),
// so this function re-checks the transaction against Paystack's own record
// before the app treats the payment as real.
//
// A confirmed charge is also written to public.payments here, so the admin
// dashboard sees it. This is the only place that can do it: payments is
// admin-only under RLS, so the paying customer cannot insert their own row.
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

/** Human-readable invoice line derived from the metadata the app attached. */
function describePayment(meta: Record<string, unknown>): string {
  const kind = typeof meta.type === "string" ? meta.type : null;
  const plan = typeof meta.plan === "string" ? meta.plan : null;
  if (kind === "subscription") {
    return plan ? `Subscription payment — ${plan}` : "Subscription payment";
  }
  if (kind === "pickup_request_pay_as_you_go") {
    const bins = typeof meta.bin_types === "string" ? meta.bin_types : null;
    return bins
      ? `Pay-as-you-go pickup — ${bins}`
      : "Pay-as-you-go pickup request";
  }
  return "Paystack payment";
}

/**
 * Records a verified charge as a paid invoice for the admin dashboard.
 *
 * Uses the service role because payments is admin-only under RLS. Failures are
 * logged but never surfaced to the caller: the customer's money has already
 * moved, so a bookkeeping problem must not tell them the payment failed.
 */
async function recordPayment(
  // deno-lint-ignore no-explicit-any
  data: any,
  userId: string,
): Promise<void> {
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!serviceRoleKey) {
    console.error("[Paystack] SUPABASE_SERVICE_ROLE_KEY is not set — payment not recorded.");
    return;
  }

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, serviceRoleKey);

  // payments.customer_id is FK-constrained to customers, so a payment from an
  // account without a customer row (staff testing, say) is logged, not forced.
  const { data: customer } = await admin
    .from("customers")
    .select("id")
    .eq("id", userId)
    .maybeSingle();

  if (!customer) {
    console.error(
      `[Paystack] No customer row for uid ${userId} — payment ${data.reference} not recorded.`,
    );
    return;
  }

  const { data: profile } = await admin
    .from("profiles")
    .select("full_name, email")
    .eq("id", userId)
    .maybeSingle();

  const meta = (data.metadata ?? {}) as Record<string, unknown>;
  // Paystack reports the smallest unit (pesewas); payments.amount is GHS.
  const amountMajor = Number(data.amount) / 100;
  const paidAt = data.paid_at ?? new Date().toISOString();

  const { error } = await admin.from("payments").upsert(
    {
      customer_id: userId,
      customer_name: profile?.full_name ?? null,
      customer_email: profile?.email ?? data.customer?.email ?? null,
      amount: amountMajor,
      status: "paid",
      // The dashboard groups by whether method contains "Paystack".
      method: data.channel ? `Paystack (${data.channel})` : "Paystack",
      billing_cycle: typeof meta.plan === "string" ? meta.plan : null,
      description: describePayment(meta),
      payment_reference: data.reference,
      invoice_date: paidAt,
      paid_at: paidAt,
      updated_at: new Date().toISOString(),
    },
    { onConflict: "payment_reference" },
  );

  if (error) {
    console.error(
      `[Paystack] Failed to record payment ${data.reference}: ${error.message}`,
    );
    return;
  }
  console.log(`[Paystack] Recorded payment ${data.reference} for uid ${userId}.`);
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
      await recordPayment(data, user.id);
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
