import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";

const locationSchema = z.object({
  code: z.string(),
  display_name: z.string(),
  id: z.guid(),
  location_type: z.enum(["receiving", "available", "quarantine", "damaged"]),
});

const warehouseSchema = z.object({
  code: z.string(),
  display_name: z.string(),
  id: z.guid(),
  locations: z.array(locationSchema),
  timezone: z.string(),
});

const inventoryItemSchema = z.object({
  display_name: z.string(),
  id: z.guid(),
  inventory_mode: z.enum(["fungible", "serialized"]),
  item_code: z.string(),
  unit_code: z.string(),
});

const inventoryPositionSchema = z.object({
  account_id: z.guid(),
  available: z.coerce.number(),
  item_code: z.string(),
  item_id: z.guid(),
  item_name: z.string(),
  location_name: z.string(),
  on_hand: z.coerce.number(),
  reserved: z.coerce.number(),
  stock_state: z.string(),
  unit_code: z.string(),
  warehouse_id: z.guid(),
  warehouse_name: z.string(),
});

const reservableOrderLineSchema = z.object({
  control_profile_code: z.string(),
  id: z.guid(),
  item_code: z.string(),
  item_id: z.guid(),
  item_name: z.string(),
  line_number: z.number().int().positive(),
  order_id: z.guid(),
  order_reference: z.string(),
  order_status: z.string(),
  order_version: z.number().int().positive().safe(),
  ordering_party_name: z.string(),
  quantity_approved: z.coerce.number().positive(),
  quantity_fulfilled: z.coerce.number().nonnegative(),
  quantity_reserved: z.coerce.number().nonnegative(),
  status: z.string(),
  unit_code: z.string(),
});

const reservationSchema = z.object({
  effective_status: z.enum(["active", "elapsed", "released", "expired", "consumed"]),
  expires_at: z.string(),
  id: z.guid(),
  item_code: z.string(),
  item_name: z.string(),
  line_number: z.number().int().positive(),
  location_name: z.string(),
  order_line_id: z.guid(),
  order_reference: z.string(),
  public_reference: z.string(),
  quantity: z.coerce.number().positive(),
  reserved_at: z.string(),
  status: z.enum(["active", "released", "expired", "consumed"]),
  version: z.number().int().positive().safe(),
  warehouse_id: z.guid(),
  warehouse_name: z.string(),
});

const inventoryTransactionSchema = z.object({
  id: z.guid(),
  is_reversed: z.boolean(),
  item_code: z.string(),
  item_name: z.string(),
  posted_at: z.string(),
  quantity_delta: z.coerce.number(),
  reason: z.string(),
  reversal_of_id: z.guid().nullable(),
  source_reference: z.string(),
  transaction_type: z.enum(["receipt", "reversal"]),
  warehouse_id: z.guid(),
  warehouse_name: z.string(),
});

const inventoryWorkspaceSchema = z.object({
  items: z.array(inventoryItemSchema),
  order_lines: z.array(reservableOrderLineSchema),
  positions: z.array(inventoryPositionSchema),
  reservations: z.array(reservationSchema),
  transactions: z.array(inventoryTransactionSchema),
  warehouses: z.array(warehouseSchema),
});

const receiptItemIdsSchema = z.array(z.guid());

export type InventoryWorkspace = z.infer<typeof inventoryWorkspaceSchema>;

export type InventoryResult =
  | { ok: true; data: InventoryWorkspace }
  | { ok: false; code: "access_denied" | "invalid_response" | "query_failed" };

export async function getStaffInventoryWorkspace(
  client: SupabaseClient,
): Promise<InventoryResult> {
  const { data, error } = await client.rpc("get_staff_inventory_workspace");
  if (error) {
    console.error(`[staff-inventory:workspace] ${error.message}`);
    return {
      ok: false,
      code:
        error.message.includes("permission_denied") ||
        error.message.includes("authentication_required")
          ? "access_denied"
          : "query_failed",
    };
  }

  const parsed = inventoryWorkspaceSchema.safeParse(data);
  if (!parsed.success) {
    console.error("[staff-inventory:workspace] Supabase returned an unexpected response shape.");
    return { ok: false, code: "invalid_response" };
  }
  const { data: receiptItemIds, error: receiptOptionsError } = await client.rpc(
    "get_staff_inventory_receipt_item_ids",
  );
  if (receiptOptionsError) {
    console.error(`[staff-inventory:receipt-options] ${receiptOptionsError.message}`);
    return { ok: false, code: "query_failed" };
  }
  const parsedReceiptItemIds = receiptItemIdsSchema.safeParse(receiptItemIds);
  if (!parsedReceiptItemIds.success) {
    console.error("[staff-inventory:receipt-options] Supabase returned an unexpected response shape.");
    return { ok: false, code: "invalid_response" };
  }
  return {
    ok: true,
    data: {
      ...parsed.data,
      items: parsed.data.items.filter((item) => parsedReceiptItemIds.data.includes(item.id)),
    },
  };
}
