import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";

const destinationSchema = z.object({
  active: z.boolean(),
  code: z.string(),
  configuration: z.record(z.string(), z.unknown()),
  created_at: z.string(),
  destination_type: z.enum(["google_sheets", "discord_channel"]),
  display_name: z.string(),
  external_reference: z.string().nullable(),
  id: z.guid(),
  updated_at: z.string(),
  version: z.number().int().positive().safe(),
  visibility: z.enum(["public", "dealer_private", "staff_private"]),
});

const columnSchema = z.object({ key: z.string(), label: z.string() });

const definitionSchema = z.object({
  active: z.boolean(),
  code: z.string(),
  column_contract: z.array(columnSchema),
  created_at: z.string(),
  destination_id: z.guid(),
  display_name: z.string(),
  id: z.guid(),
  next_run_at: z.string(),
  projection_code: z.enum([
    "public_catalogue",
    "public_dealers",
    "public_licenses",
  ]),
  refresh_interval_minutes: z.number().int().positive(),
  sheet_tab_name: z.string(),
  updated_at: z.string(),
  version: z.number().int().positive().safe(),
  visibility: z.literal("public"),
});

const exportRunSchema = z.object({
  attempt_count: z.number().int().nonnegative(),
  checksum: z.string().nullable(),
  created_at: z.string(),
  definition_code: z.string(),
  destination_version: z.string().nullable(),
  generated_at: z.string().nullable(),
  id: z.guid(),
  last_error: z.string().nullable(),
  row_count: z.number().int().nonnegative().nullable(),
  scheduled_for: z.string(),
  status: z.enum(["queued", "processing", "delivered", "failed", "cancelled"]),
});

const deliverySchema = z.object({
  attempt_count: z.number().int().nonnegative(),
  created_at: z.string(),
  delivered_at: z.string().nullable(),
  destination_code: z.string(),
  event_type: z.string(),
  external_message_id: z.string().nullable(),
  id: z.guid(),
  last_error: z.string().nullable(),
  status: z.enum(["queued", "processing", "delivered", "failed", "cancelled"]),
});

const workspaceSchema = z.object({
  definitions: z.array(definitionSchema),
  deliveries: z.array(deliverySchema),
  destinations: z.array(destinationSchema),
  export_runs: z.array(exportRunSchema),
  generated_at: z.string(),
  outbox: z.object({
    failed: z.number().int().nonnegative(),
    pending: z.number().int().nonnegative(),
    processing: z.number().int().nonnegative(),
  }),
  scheduler: z.object({
    active: z.boolean(),
    last_run_at: z.string().nullable(),
    last_run_status: z.string().nullable(),
  }),
});

export type StaffIntegrationWorkspace = z.infer<typeof workspaceSchema>;

export type StaffIntegrationResult =
  | { ok: true; data: StaffIntegrationWorkspace }
  | { ok: false; code: "access_denied" | "invalid_response" | "query_failed" };

export async function getStaffIntegrationWorkspace(
  client: SupabaseClient,
): Promise<StaffIntegrationResult> {
  const { data, error } = await client.rpc("get_staff_integration_workspace");
  if (error) {
    console.error(`[staff-integrations:workspace] ${error.message}`);
    const accessDenied =
      error.message.includes("staff_permission_denied") ||
      error.message.includes("staff_authentication_required");
    return { ok: false, code: accessDenied ? "access_denied" : "query_failed" };
  }
  const parsed = workspaceSchema.safeParse(data);
  if (!parsed.success) {
    console.error("[staff-integrations:workspace] Supabase returned an unexpected response shape.");
    return { ok: false, code: "invalid_response" };
  }
  return { ok: true, data: parsed.data };
}

export function googleSpreadsheetUrl(spreadsheetId: string): string {
  return `https://docs.google.com/spreadsheets/d/${encodeURIComponent(spreadsheetId)}/edit`;
}
