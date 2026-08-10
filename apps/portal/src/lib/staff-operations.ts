import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";

const assignmentSchema = z.object({
  active_now: z.boolean(),
  assignment_scope: z.record(z.string(), z.unknown()),
  effective_from: z.string(),
  effective_until: z.string().nullable(),
  id: z.guid(),
  is_elevated: z.boolean(),
  revoked_at: z.string().nullable(),
  role_code: z.string(),
  role_id: z.guid(),
  role_name: z.string(),
});

const actorSchema = z.object({
  assignments: z.array(assignmentSchema),
  display_name: z.string(),
  id: z.guid(),
  status: z.enum(["active", "disabled"]),
});

const roleSchema = z.object({
  code: z.string(),
  description: z.string(),
  display_name: z.string(),
  id: z.guid(),
  is_elevated: z.boolean(),
  permissions: z.array(z.object({ code: z.string(), display_name: z.string() })),
});

const auditSchema = z.object({
  action: z.string(),
  actor_id: z.guid().nullable(),
  actor_name: z.string().nullable(),
  created_at: z.string(),
  id: z.guid(),
  new_state: z.unknown().nullable(),
  previous_state: z.unknown().nullable(),
  reason: z.string().nullable(),
  record_id: z.guid().nullable(),
  record_type: z.string(),
  request_id: z.guid().nullable(),
  source_surface: z.string(),
});

const healthSchema = z.object({
  asset_reservations_expired_active: z.number().int().nonnegative(),
  compliance_open: z.number().int().nonnegative(),
  delivery_failed: z.number().int().nonnegative(),
  delivery_lease_expired: z.number().int().nonnegative(),
  export_definitions_overdue: z.number().int().nonnegative(),
  export_failed: z.number().int().nonnegative(),
  export_lease_expired: z.number().int().nonnegative(),
  outbox_failed: z.number().int().nonnegative(),
  outbox_pending: z.number().int().nonnegative(),
  reservations_expired_active: z.number().int().nonnegative(),
  transfers_in_transit: z.number().int().nonnegative(),
});

const workspaceSchema = z.object({
  actors: z.array(actorSchema),
  capabilities: z.object({
    can_manage_assignments: z.boolean(),
    can_read_audit: z.boolean(),
  }),
  generated_at: z.string(),
  health: healthSchema,
  recent_access_audit: z.array(auditSchema),
  roles: z.array(roleSchema),
});

export type StaffOperationsWorkspace = z.infer<typeof workspaceSchema>;

export type StaffOperationsResult =
  | { ok: true; data: StaffOperationsWorkspace }
  | { ok: false; code: "access_denied" | "invalid_response" | "query_failed" };

export async function getStaffOperationsWorkspace(
  client: SupabaseClient,
): Promise<StaffOperationsResult> {
  const { data, error } = await client.rpc("get_staff_operations_workspace");
  if (error) {
    console.error(`[staff-operations:workspace] ${error.message}`);
    const denied =
      error.message.includes("staff_permission_denied") ||
      error.message.includes("staff_authentication_required");
    return { ok: false, code: denied ? "access_denied" : "query_failed" };
  }
  const parsed = workspaceSchema.safeParse(data);
  if (!parsed.success) {
    console.error("[staff-operations:workspace] Unexpected authoritative response.");
    return { ok: false, code: "invalid_response" };
  }
  return { ok: true, data: parsed.data };
}
