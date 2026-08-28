// Supabase Edge Function: admin-delete-user
//
// Removes a panel user's account outright. Deactivating (profiles.status) is
// the reversible option and should usually be preferred; this exists for the
// account created by mistake, where leaving a disabled row around is just
// clutter.
//
// Deleting reaches into auth.users, which needs the service_role key and so can
// never happen from the browser. profiles.id is FK'd to auth.users with
// `on delete cascade`, so removing the auth user takes the profile with it.

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

  if (callerProfile?.role !== "admin" || callerProfile?.status !== "active") {
    return jsonResponse({ error: "Only an admin can delete panel users." }, 403);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid request body." }, 400);
  }

  const userId = body.userId as string | undefined;
  if (!userId || typeof userId !== "string") {
    return jsonResponse({ error: "userId is required." }, 400);
  }

  if (userId === caller.id) {
    return jsonResponse({ error: "You cannot delete your own account." }, 400);
  }

  const { data: target } = await supabaseAdmin
    .from("profiles")
    .select("role, full_name")
    .eq("id", userId)
    .single();

  if (!target) {
    return jsonResponse({ error: "That user no longer exists." }, 404);
  }

  // This endpoint is for back-office accounts. Customers and riders own rows in
  // other tables and belong to the app's own account lifecycle, so deleting one
  // here would be a much larger, quieter action than the caller intended.
  if (!BACK_OFFICE_ROLES.includes(target.role)) {
    return jsonResponse(
      { error: "Only panel users can be deleted here, not customers or riders." },
      400,
    );
  }

  // Removing the last admin would leave nobody able to create panel users or
  // undo it — there is no way back from that without direct database access.
  if (target.role === "admin") {
    const { count } = await supabaseAdmin
      .from("profiles")
      .select("id", { count: "exact", head: true })
      .eq("role", "admin")
      .eq("status", "active");

    if ((count ?? 0) <= 1) {
      return jsonResponse(
        { error: "This is the only active administrator and cannot be deleted." },
        400,
      );
    }
  }

  const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(userId);
  if (deleteError) {
    return jsonResponse({ error: deleteError.message }, 400);
  }

  await supabaseAdmin.from("admin_notifications").insert({
    title: "Panel User Removed",
    message: `${target.full_name ?? "A panel user"} was deleted by ${caller.email ?? "an administrator"}.`,
    type: "staff_removed",
  });

  return jsonResponse({ ok: true });
});
