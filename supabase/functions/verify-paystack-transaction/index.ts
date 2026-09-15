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
// A subscription charge buys a period of cover (grant_subscription_period),
// which is what makes the customer's scheduled pickups appear.
//
// A pay-as-you-go charge additionally becomes one row in
// public.payg_pickup_credits, which schedule_pickup consumes when the customer
// requests the pickup they paid for. Customers cannot write that table either.
//
// SETUP: uses the same PAYSTACK_SECRET_KEY secret as initialize-paystack-transaction.
//
// Expected request body:
//   { reference: string, expected_amount?: number, expected_currency?: string }
// Returns:
//   { verified: boolean, status: string, amount: number, currency: string,
//     reference: string, pickup_credit: boolean }

import { createClient } from "@supabase/supabase-js";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

/** Metadata type the app sends when a customer prepays one PAYG pickup. */
const PAYG_CREDIT_TYPE = "payg_pickup_credit";
/** Older app builds charge inside the pickup form; still worth one pickup. */
const LEGACY_PAYG_PICKUP_TYPE = "pickup_request_pay_as_you_go";

function adminClient() {
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!serviceRoleKey) return null;
  return createClient(Deno.env.get("SUPABASE_URL")!, serviceRoleKey);
}

function numberOr(value: unknown, fallback: number): number {
  const n = typeof value === "number" ? value : Number(value);
  return Number.isFinite(n) ? n : fallback;
}

function percentage(value: unknown): number {
  return Math.min(100, Math.max(0, numberOr(value, 0)));
}

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
  if (kind === PAYG_CREDIT_TYPE) {
    return "Pay-as-you-go pickup (prepaid)";
  }
  if (kind === LEGACY_PAYG_PICKUP_TYPE) {
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
  const admin = adminClient();
  if (!admin) {
    console.error("[Paystack] SUPABASE_SERVICE_ROLE_KEY is not set — payment not recorded.");
    return;
  }

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

/**
 * Turns a verified pay-as-you-go charge into one prepaid pickup.
 *
 * Idempotent on the Paystack reference, since the same charge can be verified
 * more than once. Returns whether a credit exists for this reference.
 */
async function grantPickupCredit(
  // deno-lint-ignore no-explicit-any
  data: any,
  userId: string,
): Promise<boolean> {
  const meta = (data.metadata ?? {}) as Record<string, unknown>;
  if (meta.type !== PAYG_CREDIT_TYPE && meta.type !== LEGACY_PAYG_PICKUP_TYPE) {
    return false;
  }

  // initialize-paystack-transaction stamps the payer's uid into the metadata.
  // Without this check anyone could verify someone else's reference and take
  // the pickup it paid for.
  if (meta.user_uid !== userId) {
    console.warn(`[Paystack] Reference ${data.reference} belongs to another user — no pickup credit for uid ${userId}.`);
    return false;
  }

  const admin = adminClient();
  if (!admin) {
    console.error(`[Paystack] SUPABASE_SERVICE_ROLE_KEY is not set — no pickup credit for ${data.reference}.`);
    return false;
  }

  // Charges taken by older app builds were spent on a pickup directly, before
  // credits existed. Re-verifying one must not mint a second, free pickup.
  const { data: spent } = await admin
    .from("pickup_requests")
    .select("id")
    .eq("payment_reference", data.reference)
    .limit(1);
  const { data: existing } = await admin
    .from("payg_pickup_credits")
    .select("id")
    .eq("payment_reference", data.reference)
    .limit(1);
  if (spent?.length && !existing?.length) {
    return false;
  }

  // Paystack reports pesewas. The gross amount is what Paystack itself
  // confirmed; the app's net figure (after Paystack's fee) is only trusted
  // when it does not exceed that.
  const charged = Number(data.amount) / 100;
  const net = Math.min(numberOr(meta.net_total, charged), charged);
  const method = typeof meta.payment_method === "string" && meta.payment_method
    ? `Paystack (${meta.payment_method})`
    : data.channel ? `Paystack (${data.channel})` : "Paystack";

  const { error } = await admin.from("payg_pickup_credits").upsert(
    {
      customer_id: userId,
      payment_reference: data.reference,
      amount: Math.round(net * 100) / 100,
      amount_charged: charged,
      original_amount: numberOr(meta.original_total, net),
      discount_applied_percentage: percentage(meta.discount_percentage),
      surcharge_applied_percentage: percentage(meta.surcharge_percentage),
      payment_method: method,
      paid_at: data.paid_at ?? new Date().toISOString(),
    },
    { onConflict: "payment_reference", ignoreDuplicates: true },
  );

  if (error) {
    console.error(`[Paystack] Failed to grant pickup credit for ${data.reference}: ${error.message}`);
    return false;
  }
  console.log(`[Paystack] Pickup credit ready for ${data.reference} (uid ${userId}).`);
  return true;
}

/**
 * Turns a verified subscription charge into a paid period of cover.
 * Idempotent on the Paystack reference. Returns whether cover was granted.
 */
async function grantSubscription(
  // deno-lint-ignore no-explicit-any
  data: any,
  userId: string,
): Promise<boolean> {
  const meta = (data.metadata ?? {}) as Record<string, unknown>;
  if (meta.type !== "subscription" || typeof meta.plan !== "string") return false;

  if (meta.user_uid !== userId) {
    console.warn(`[Paystack] Subscription reference ${data.reference} belongs to another user — not granted to uid ${userId}.`);
    return false;
  }

  const admin = adminClient();
  if (!admin) {
    console.error(`[Paystack] SUPABASE_SERVICE_ROLE_KEY is not set — no subscription cover for ${data.reference}.`);
    return false;
  }

  const charged = Number(data.amount) / 100;
  const net = Math.min(numberOr(meta.net_total, charged), charged);

  const { error } = await admin.rpc("grant_subscription_period", {
    p_customer_id: userId,
    p_plan_name: meta.plan,
    p_amount: Math.round(net * 100) / 100,
    p_reference: data.reference,
    p_paid_at: data.paid_at ?? new Date().toISOString(),
  });

  if (error) {
    console.error(`[Paystack] Failed to grant subscription for ${data.reference}: ${error.message}`);
    return false;
  }
  console.log(`[Paystack] Subscription cover granted for ${data.reference} (uid ${userId}, ${meta.plan}).`);
  return true;
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
    let pickupCredit = false;
    let subscriptionGranted = false;

    if (!verified) {
      console.warn(
        `[Paystack] Verify: reference ${reference} not accepted — ` +
          `status=${data.status} amount=${data.amount} currency=${data.currency} uid=${user.id}`,
      );
    } else {
      console.log(`[Paystack] Verify: reference ${reference} confirmed — uid: ${user.id}`);
      // The credit first: it is what lets the customer use what they paid for.
      pickupCredit = await grantPickupCredit(data, user.id);
      subscriptionGranted = await grantSubscription(data, user.id);
      await recordPayment(data, user.id);
    }

    return jsonResponse({
      verified,
      status: data.status,
      amount: data.amount,
      currency: data.currency,
      reference: data.reference,
      pickup_credit: pickupCredit,
      subscription_granted: subscriptionGranted,
    });
  } catch (err) {
    console.error("[Paystack] Verify API error:", err);
    return jsonResponse(
      { verified: false, error: "Could not reach payment service. Please try again." },
      500,
    );
  }
});
