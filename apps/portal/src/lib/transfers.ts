import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";

const transferAccountSchema = z.object({
  available: z.coerce.number(),
  id: z.guid(),
  item_code: z.string(),
  item_id: z.guid(),
  item_name: z.string(),
  location_name: z.string(),
  on_hand: z.coerce.number(),
  owner_party_id: z.guid(),
  reserved: z.coerce.number(),
  warehouse_id: z.guid(),
  warehouse_name: z.string(),
});

const stockTransferSchema = z.object({
  authorized_at: z.string().nullable(),
  can_authorize: z.boolean(),
  can_cancel: z.boolean(),
  can_dispatch: z.boolean(),
  can_receive: z.boolean(),
  cancelled_at: z.string().nullable(),
  destination_location_name: z.string(),
  destination_warehouse_id: z.guid(),
  destination_warehouse_name: z.string(),
  dispatched_at: z.string().nullable(),
  disputed_at: z.string().nullable(),
  id: z.guid(),
  item_code: z.string(),
  item_name: z.string(),
  public_reference: z.string(),
  quantity: z.coerce.number().positive(),
  received_at: z.string().nullable(),
  requested_at: z.string(),
  source_location_name: z.string(),
  source_warehouse_id: z.guid(),
  source_warehouse_name: z.string(),
  status: z.enum([
    "requested",
    "authorized",
    "dispatched",
    "disputed",
    "received",
    "cancelled",
  ]),
  version: z.number().int().positive().safe(),
});

const transferWorkspaceSchema = z.object({
  accounts: z.array(transferAccountSchema),
  transfers: z.array(stockTransferSchema),
});

export type TransferWorkspace = z.infer<typeof transferWorkspaceSchema>;

export type TransferWorkspaceResult =
  | { ok: true; data: TransferWorkspace }
  | { ok: false; code: "access_denied" | "invalid_response" | "query_failed" };

export async function getStaffTransferWorkspace(
  client: SupabaseClient,
): Promise<TransferWorkspaceResult> {
  const { data, error } = await client.rpc("get_staff_transfer_workspace");
  if (error) {
    console.error(`[staff-transfers:workspace] ${error.message}`);
    return {
      ok: false,
      code:
        error.message.includes("permission_denied") ||
        error.message.includes("authentication_required")
          ? "access_denied"
          : "query_failed",
    };
  }
  const parsed = transferWorkspaceSchema.safeParse(data);
  if (!parsed.success) {
    console.error("[staff-transfers:workspace] Unexpected Supabase response.");
    return { ok: false, code: "invalid_response" };
  }
  return { ok: true, data: parsed.data };
}
