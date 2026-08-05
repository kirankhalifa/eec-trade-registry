import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";

const readyReservationSchema = z.object({
  expires_at: z.string(),
  fulfillment_mode: z.enum(["collection", "delivery", "consignment"]),
  id: z.guid(),
  item_code: z.string(),
  item_name: z.string(),
  line_number: z.number().int().positive(),
  location_name: z.string(),
  order_id: z.guid(),
  order_line_id: z.guid(),
  order_reference: z.string(),
  ordering_party_name: z.string(),
  public_reference: z.string(),
  quantity: z.coerce.number().positive(),
  quantity_approved: z.coerce.number().positive(),
  quantity_fulfilled: z.coerce.number().nonnegative(),
  unit_code: z.string(),
  version: z.number().int().positive().safe(),
  warehouse_id: z.guid(),
  warehouse_name: z.string(),
});

const fulfillmentSchema = z.object({
  can_reverse: z.boolean(),
  completed_at: z.string(),
  fulfillment_mode: z.enum(["collection", "delivery", "consignment"]),
  id: z.guid(),
  inventory_transaction_id: z.guid(),
  item_code: z.string(),
  item_name: z.string(),
  line_number: z.number().int().positive(),
  order_reference: z.string(),
  ordering_party_name: z.string(),
  public_reference: z.string(),
  quantity: z.coerce.number().positive(),
  reversal_transaction_id: z.guid().nullable(),
  reversed_at: z.string().nullable(),
  status: z.enum(["completed", "reversed"]),
  unit_code: z.string(),
  version: z.number().int().positive().safe(),
  warehouse_id: z.guid(),
  warehouse_name: z.string(),
});

const fulfillmentWorkspaceSchema = z.object({
  fulfillments: z.array(fulfillmentSchema),
  ready_reservations: z.array(readyReservationSchema),
});

export type FulfillmentWorkspace = z.infer<typeof fulfillmentWorkspaceSchema>;

export type FulfillmentWorkspaceResult =
  | { ok: true; data: FulfillmentWorkspace }
  | { ok: false; code: "access_denied" | "invalid_response" | "query_failed" };

export async function getStaffFulfillmentWorkspace(
  client: SupabaseClient,
): Promise<FulfillmentWorkspaceResult> {
  const { data, error } = await client.rpc("get_staff_fulfillment_workspace");
  if (error) {
    console.error(`[staff-fulfillment:workspace] ${error.message}`);
    return {
      ok: false,
      code:
        error.message.includes("permission_denied") ||
        error.message.includes("authentication_required")
          ? "access_denied"
          : "query_failed",
    };
  }

  const parsed = fulfillmentWorkspaceSchema.safeParse(data);
  if (!parsed.success) {
    console.error(
      "[staff-fulfillment:workspace] Supabase returned an unexpected response shape.",
    );
    return { ok: false, code: "invalid_response" };
  }
  return { ok: true, data: parsed.data };
}
