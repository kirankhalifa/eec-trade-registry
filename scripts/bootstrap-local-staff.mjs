import { createClient } from "@supabase/supabase-js";

const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const authUserId = process.env.LOCAL_AUTH_USER_UUID;
const displayName = process.env.LOCAL_STAFF_DISPLAY_NAME || "Local Owner";
const roleCode = process.env.LOCAL_STAFF_ROLE || "platform_administrator";

if (!url || !serviceRoleKey || !authUserId) {
  throw new Error("Set NEXT_PUBLIC_SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, and LOCAL_AUTH_USER_UUID.");
}

const target = new URL(url);
if (!(["127.0.0.1", "localhost"].includes(target.hostname) && target.port === "54321")) {
  throw new Error(`Refusing bootstrap against non-local Supabase host: ${target.host}`);
}

const supabase = createClient(url, serviceRoleKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

const { data: role, error: roleError } = await supabase
  .from("staff_roles")
  .select("id")
  .eq("code", roleCode)
  .single();
if (roleError) throw roleError;

const { data: actor, error: actorError } = await supabase
  .from("actor_profiles")
  .upsert({ auth_user_id: authUserId, display_name: displayName, actor_type: "staff" }, { onConflict: "auth_user_id" })
  .select("id")
  .single();
if (actorError) throw actorError;

const { data: existing, error: existingError } = await supabase
  .from("staff_assignments")
  .select("id")
  .eq("actor_id", actor.id)
  .eq("staff_role_id", role.id)
  .is("effective_until", null)
  .maybeSingle();
if (existingError) throw existingError;

if (!existing) {
  const { error } = await supabase.from("staff_assignments").insert({
    actor_id: actor.id,
    staff_role_id: role.id,
    assignment_scope: {},
  });
  if (error) throw error;
}

console.log(`Local-only staff bootstrap complete for ${displayName} (${roleCode}).`);
