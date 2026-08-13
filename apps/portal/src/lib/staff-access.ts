import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";

export const staffAccessStateSchema = z.object({
  access_class: z.enum(["owner", "agent"]).nullable(),
  display_name: z.string().nullable(),
  last_attempted_at: z.string().nullable(),
  request_id: z.guid().nullable(),
  requested_at: z.string().nullable(),
  review_reason: z.string().nullable(),
  reviewed_at: z.string().nullable(),
  state: z.enum(["authorized", "pending", "denied", "blocked", "unregistered"]),
});

const accessRequestSchema = z.object({
  discord_user_id: z.string(),
  display_name: z.string(),
  id: z.guid(),
  last_attempted_at: z.string(),
  protected_owner: z.boolean(),
  requested_at: z.string(),
  review_reason: z.string().nullable(),
  reviewed_at: z.string().nullable(),
  status: z.enum(["pending", "approved", "denied", "blocked"]),
  version: z.number().int().positive(),
});

const ownerAccessWorkspaceSchema = z.object({
  generated_at: z.string(),
  requests: z.array(accessRequestSchema),
  staff: z.array(z.object({
    access_class: z.enum(["owner", "agent"]),
    active_since: z.string(),
    actor_id: z.guid(),
    discord_user_id: z.string().nullable(),
    display_name: z.string(),
    status: z.enum(["active", "disabled"]),
  })),
});

export type StaffAccessState = z.infer<typeof staffAccessStateSchema>;
export type OwnerAccessWorkspace = z.infer<typeof ownerAccessWorkspaceSchema>;

export async function getMyStaffAccessState(client: SupabaseClient) {
  const { data, error } = await client.rpc("get_my_staff_access_state");
  if (error) {
    console.error(`[staff-access:state] ${error.code ?? "unknown"}`);
    return { ok: false as const };
  }
  const parsed = staffAccessStateSchema.safeParse(data);
  if (!parsed.success) {
    console.error("[staff-access:state] Unexpected authoritative response.");
    return { ok: false as const };
  }
  return { ok: true as const, data: parsed.data };
}

export async function registerStaffAccessRequest(client: SupabaseClient) {
  const { data, error } = await client.rpc("register_staff_access_request", {
    p_request_id: crypto.randomUUID(),
  });
  if (error) {
    console.error(`[staff-access:register] ${error.code ?? "unknown"}`);
    return { ok: false as const };
  }
  const parsed = staffAccessStateSchema.safeParse(data);
  if (!parsed.success) {
    console.error("[staff-access:register] Unexpected authoritative response.");
    return { ok: false as const };
  }
  return { ok: true as const, data: parsed.data };
}

export async function getOwnerAccessWorkspace(client: SupabaseClient) {
  const { data, error } = await client.rpc("get_owner_access_workspace");
  if (error) {
    console.error(`[staff-access:workspace] ${error.code ?? "unknown"}`);
    const denied = error.code === "42501" || error.message.includes("permission_denied");
    return { ok: false as const, denied };
  }
  const parsed = ownerAccessWorkspaceSchema.safeParse(data);
  if (!parsed.success) {
    console.error("[staff-access:workspace] Unexpected authoritative response.", parsed.error.issues);
    return { ok: false as const, denied: false };
  }
  return { ok: true as const, data: parsed.data };
}
