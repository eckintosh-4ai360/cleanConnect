// Supabase Edge Function: admin-create-user
//
// The admin panel's "New Customer Account" / "Register Rider" forms used to
// just addDoc a shell Firestore record. Postgres's customers/riders tables
// have a hard FK to auth.users, so creating one now means creating a real
// auth user — which needs the service_role key, so it can never happen
// directly from the browser (shipping that key in the SPA bundle would let
// anyone bypass RLS entirely). This function holds the service role key
// server-side, checks the caller is a real admin first, creates the auth
// user (random password, never surfaced), applies any role-specific fields
// the form collected, and emails a password-reset link so the new
// customer/rider can set their own password.
//
// It also creates back-office (admin panel) accounts — admin, financial
// secretary, supervisor, staff, support. Those hand out panel privileges, so
// unlike customer/rider they may only be created by a true 'admin', not by
// every panel user.

import { createClient } from "@supabase/supabase-js";

// Kept in sync with profiles_role_check and admin_panel/src/roles.js.
const BACK_OFFICE_ROLES = ["admin", "financial_secretary", "supervisor", "staff", "support"];

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
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

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse({ error: "Missing authorization header." }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseAsCaller = createClient(
    supabaseUrl,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const {
    data: { user: caller },
  } = await supabaseAsCaller.auth.getUser();
  if (!caller) {
    return jsonResponse({ error: "Invalid session." }, 401);
  }

  const supabaseAdmin = createClient(
    supabaseUrl,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: callerProfile } = await supabaseAdmin
    .from("profiles")
    .select("role, status")
    .eq("id", caller.id)
    .single();

  const callerRole = callerProfile?.role ?? "";
  if (!BACK_OFFICE_ROLES.includes(callerRole) || callerProfile?.status !== "active") {
    return jsonResponse({ error: "Admin access required." }, 403);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid request body." }, 400);
  }

  const email = body.email as string | undefined;
  const fullName = body.fullName as string | undefined;
  const phoneNumber = (body.phoneNumber as string | undefined) ?? null;
  const role = body.role as string | undefined;
  const extra = (body.extra as Record<string, unknown> | undefined) ?? {};
  // Where the password-setup link should land. The caller supplies it because
  // only the browser knows which origin the panel is being served from; without
  // it Supabase falls back to the project's Site URL, which points at the
  // customer app and leaves a new panel user with nowhere to set a password.
  const redirectTo = typeof body.redirectTo === "string" && body.redirectTo
    ? body.redirectTo
    : undefined;

  if (!email || typeof email !== "string") {
    return jsonResponse({ error: "A valid email address is required." }, 400);
  }
  if (!fullName || typeof fullName !== "string") {
    return jsonResponse({ error: "A full name is required." }, 400);
  }
  const isBackOfficeRole = BACK_OFFICE_ROLES.includes(role ?? "");
  if (role !== "customer" && role !== "rider" && !isBackOfficeRole) {
    return jsonResponse({ error: `role must be one of: customer, rider, ${BACK_OFFICE_ROLES.join(", ")}.` }, 400);
  }
  // Creating a panel account grants panel privileges, so only a full admin may
  // do it — a support agent creating themselves an admin colleague would be an
  // escalation path around is_super_admin().
  if (isBackOfficeRole && callerRole !== "admin") {
    return jsonResponse({ error: "Only an admin can create panel user accounts." }, 403);
  }

  const tempPassword = crypto.randomUUID();
  const { data: created, error: createError } = await supabaseAdmin.auth.admin.createUser({
    email,
    password: tempPassword,
    email_confirm: true,
    user_metadata: { full_name: fullName, phone_number: phoneNumber, role },
  });

  if (createError || !created?.user) {
    return jsonResponse({ error: createError?.message ?? "Failed to create account." }, 400);
  }

  if (!isBackOfficeRole && Object.keys(extra).length > 0) {
    const table = role === "customer" ? "customers" : "riders";
    const { error: updateError } = await supabaseAdmin
      .from(table)
      .update(extra)
      .eq("id", created.user.id);
    if (updateError) {
      console.error(`[admin-create-user] failed to apply extra ${table} fields:`, updateError);
    }
  }

  const { error: resetError } = await supabaseAdmin.auth.resetPasswordForEmail(
    email,
    redirectTo ? { redirectTo } : undefined,
  );
  if (resetError) {
    console.error("[admin-create-user] failed to send password-reset email:", resetError);
  }

  // The account exists either way, so this is not an error — but the caller
  // needs to know the invite did not go out so it can tell the admin to resend.
  return jsonResponse({ id: created.user.id, inviteSent: !resetError });
});
