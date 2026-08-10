import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";

const nullableNumber = z.union([z.coerce.number(), z.null()]);

const positionSchema = z.object({
  admin_receipt_allowed: z.boolean(),
  available: z.coerce.number(),
  backordered: z.coerce.number(),
  business_bulk_review_threshold: nullableNumber,
  committed_7d_minor: z.coerce.number(),
  critical_level: nullableNumber,
  direct_individual_allowed: z.boolean(),
  direct_weekly_limit: nullableNumber,
  item_code: z.string(),
  item_id: z.guid(),
  item_name: z.string(),
  minimum_level: nullableNumber,
  on_hand: z.coerce.number(),
  paid_7d_minor: z.coerce.number(),
  player_sourced_only: z.boolean(),
  policy_version: z.number().int().positive().safe(),
  procured_7d: z.coerce.number(),
  procurement_enabled: z.boolean(),
  reserve_state: z.enum(["unconfigured", "critical", "below_minimum", "building", "target_met", "surplus"]),
  reserved: z.coerce.number(),
  supply_mode: z.enum(["warehouse_stocked", "player_sourced_reserve", "made_to_order", "limited_release", "serialized_unique"]),
  surplus_level: nullableNumber,
  target_level: nullableNumber,
  unit_code: z.string(),
});

const offerSchema = z.object({
  amount_minor: z.coerce.number().int().positive(),
  currency_code: z.string(),
  currency_id: z.guid(),
  currency_symbol: z.string(),
  effective_from: z.string(),
  effective_until: z.string().nullable(),
  id: z.guid(),
  is_current: z.boolean(),
  item_code: z.string(),
  item_id: z.guid(),
  item_name: z.string(),
  minimum_quantity: z.coerce.number().positive(),
  notes: z.string(),
  staff_review_quantity: nullableNumber,
  status: z.enum(["draft", "active", "retired"]),
  unit_code: z.string(),
  version: z.number().int().positive().safe(),
});

const supplierSchema = z.object({
  display_name: z.string(),
  id: z.guid(),
  legal_name: z.string(),
  notes: z.string(),
  party_id: z.guid(),
  party_type_code: z.string(),
  public_reference: z.string(),
  status: z.enum(["active", "suspended", "closed"]),
  version: z.number().int().positive().safe(),
});

const deliverySchema = z.object({
  amount_minor_per_unit: z.coerce.number().int().positive(),
  currency_code: z.string(),
  id: z.guid(),
  is_reversed: z.boolean(),
  item_code: z.string(),
  item_id: z.guid(),
  item_name: z.string(),
  location_name: z.string(),
  public_reference: z.string(),
  quantity: z.coerce.number().positive(),
  received_at: z.string(),
  settled_at: z.string().nullable(),
  settlement_reference: z.string().nullable(),
  settlement_status: z.enum(["pending", "paid"]),
  supplier_id: z.guid(),
  supplier_name: z.string(),
  total_amount_minor: z.coerce.number().int().positive(),
  unit_code: z.string(),
  version: z.number().int().positive().safe(),
  warehouse_name: z.string(),
});

const workspaceSchema = z.object({
  currencies: z.array(z.object({
    code: z.string(), display_name: z.string(), id: z.guid(),
    minor_unit_scale: z.number().int().nonnegative(), symbol: z.string(),
  })),
  deliveries: z.array(deliverySchema),
  generated_at: z.string(),
  jurisdictions: z.array(z.object({ code: z.string(), display_name: z.string(), id: z.guid() })),
  offers: z.array(offerSchema),
  party_types: z.array(z.object({ code: z.string(), display_name: z.string() })),
  positions: z.array(positionSchema),
  suppliers: z.array(supplierSchema),
  warehouses: z.array(z.object({
    display_name: z.string(), id: z.guid(), locations: z.array(z.object({
      display_name: z.string(), id: z.guid(), location_type: z.enum(["receiving", "available"]),
    })),
  })),
});

export type EconomyWorkspace = z.infer<typeof workspaceSchema>;
export type EconomyResult =
  | { ok: true; data: EconomyWorkspace }
  | { ok: false; code: "access_denied" | "invalid_response" | "query_failed" };

export async function getStaffEconomyWorkspace(client: SupabaseClient): Promise<EconomyResult> {
  const { data, error } = await client.rpc("get_staff_economy_workspace");
  if (error) {
    console.error(`[staff-economy:workspace] ${error.message}`);
    return { ok: false, code: error.code === "42501" || error.message.includes("permission_denied")
      ? "access_denied" : "query_failed" };
  }
  const parsed = workspaceSchema.safeParse(data);
  if (!parsed.success) {
    console.error("[staff-economy:workspace] Supabase returned an unexpected response shape.");
    return { ok: false, code: "invalid_response" };
  }
  return { ok: true, data: parsed.data };
}
