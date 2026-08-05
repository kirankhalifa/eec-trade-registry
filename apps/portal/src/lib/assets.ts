import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";

const assetReservationSchema = z.object({
  expires_at: z.string(),
  id: z.guid(),
  order_line_id: z.guid(),
  order_reference: z.string(),
  public_reference: z.string(),
  version: z.number().int().positive().safe(),
});

const assetSchema = z.object({
  active_reservation: assetReservationSchema.nullable(),
  condition_code: z.enum(["excellent", "good", "fair", "damaged", "unknown"]),
  custodian_party_name: z.string(),
  id: z.guid(),
  item_code: z.string(),
  item_id: z.guid(),
  item_name: z.string(),
  location_name: z.string().nullable(),
  next_inspection_due_at: z.string().nullable(),
  owner_party_name: z.string(),
  public_reference: z.string(),
  registered_at: z.string(),
  serial_marking: z.string().nullable(),
  status: z.enum([
    "available", "reserved", "in_custody", "missing",
    "damaged", "seized", "retired", "destroyed",
  ]),
  version: z.number().int().positive().safe(),
  warehouse_name: z.string().nullable(),
});

const workspaceSchema = z.object({
  assets: z.array(assetSchema),
  capabilities: z.object({
    can_inspect: z.boolean(),
    can_manage_lifecycle: z.boolean(),
    can_register: z.boolean(),
    can_reserve: z.boolean(),
    can_transfer: z.boolean(),
  }),
  items: z.array(z.object({
    display_name: z.string(), id: z.guid(), item_code: z.string(),
  })),
  locations: z.array(z.object({
    custodian_party_id: z.guid(), display_name: z.string(), id: z.guid(),
    warehouse_id: z.guid(), warehouse_name: z.string(),
  })),
  order_lines: z.array(z.object({
    id: z.guid(), item_code: z.string(), item_id: z.guid(), item_name: z.string(),
    line_number: z.number().int().positive(), order_reference: z.string(),
    ordering_party_name: z.string(),
  })),
  parties: z.array(z.object({ display_name: z.string(), id: z.guid() })),
});

export type AssetWorkspace = z.infer<typeof workspaceSchema>;
export type AssetWorkspaceResult =
  | { ok: true; data: AssetWorkspace }
  | { ok: false; code: "access_denied" | "invalid_response" | "query_failed" };

export async function getStaffAssetWorkspace(
  client: SupabaseClient,
): Promise<AssetWorkspaceResult> {
  const { data, error } = await client.rpc("get_staff_asset_workspace");
  if (error) {
    console.error(`[staff-assets:workspace] ${error.message}`);
    return {
      ok: false,
      code:
        error.message.includes("permission_denied") ||
        error.message.includes("authentication_required")
          ? "access_denied" : "query_failed",
    };
  }
  const parsed = workspaceSchema.safeParse(data);
  if (!parsed.success) {
    console.error("[staff-assets:workspace] Unexpected Supabase response.");
    return { ok: false, code: "invalid_response" };
  }
  return { ok: true, data: parsed.data };
}
