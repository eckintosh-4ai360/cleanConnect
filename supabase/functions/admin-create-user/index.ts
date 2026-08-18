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

import { createClient } from "@supabase/supabase-js";

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
    .select("role")
    .eq("id", caller.id)
    .single();

  if (callerProfile?.role !== "admin") {
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

  if (!email || typeof email !== "string") {
    return jsonResponse({ error: "A valid email address is required." }, 400);
  }
  if (!fullName || typeof fullName !== "string") {
    return jsonResponse({ error: "A full name is required." }, 400);
  }
  if (role !== "customer" && role !== "rider") {
    return jsonResponse({ error: "role must be 'customer' or 'rider'." }, 400);
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

  if (Object.keys(extra).length > 0) {
    const table = role === "customer" ? "customers" : "riders";
    const { error: updateError } = await supabaseAdmin
      .from(table)
      .update(extra)
      .eq("id", created.user.id);
    if (updateError) {
      console.error(`[admin-create-user] failed to apply extra ${table} fields:`, updateError);
    }
  }

  const { error: resetError } = await supabaseAdmin.auth.resetPasswordForEmail(email);
  if (resetError) {
    console.error("[admin-create-user] failed to send password-reset email:", resetError);
  }

  return jsonResponse({ id: created.user.id });
});
