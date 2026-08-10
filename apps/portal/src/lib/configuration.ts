import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";

const referenceBase = z.object({
  active: z.boolean(),
  code: z.string(),
  display_name: z.string(),
  id: z.guid(),
  version: z.number().int().positive().safe(),
});

const workspaceSchema = z.object({
  availability_profiles: z.array(referenceBase.extend({
    public_description: z.string(),
    sort_order: z.number().int(),
  })),
  capabilities: z.object({
    can_manage_catalogue: z.boolean(),
    can_manage_configuration: z.boolean(),
    can_manage_pricing: z.boolean(),
    can_manage_publication: z.boolean(),
    can_manage_supply_policy: z.boolean(),
    can_post_receipts: z.boolean(),
  }),
  categories: z.array(referenceBase.extend({
    description: z.string(),
    sort_order: z.number().int(),
  })),
  control_profiles: z.array(referenceBase.extend({
    public_description: z.string(),
    requires_serial_tracking: z.boolean(),
    requires_staff_review: z.boolean(),
    requires_transaction_approval: z.boolean(),
  })),
  endorsements: z.array(referenceBase.extend({
    description: z.string(),
    public_display_name: z.string(),
  })),
  generated_at: z.string(),
  items: z.array(z.object({
    admin_receipt_allowed: z.boolean(),
    availability_profile_code: z.string().nullable(),
    bulk_minimum: z.coerce.number().nullable(),
    category_code: z.string(),
    control_profile_code: z.string().nullable(),
    currency_code: z.string().nullable(),
    description: z.string(),
    display_name: z.string(),
    id: z.guid(),
    inventory_mode: z.enum(["fungible", "serialized"]),
    item_code: z.string(),
    order_increment: z.coerce.number().nullable(),
    price_amount_minor: z.coerce.number().int().nonnegative().nullable(),
    price_schedule_id: z.guid().nullable(),
    procurement_enabled: z.boolean(),
    public_description: z.string().nullable(),
    public_name: z.string().nullable(),
    publication_status: z.enum(["draft", "published", "withdrawn"]).nullable(),
    requirement_summary: z.string().nullable(),
    slug: z.string(),
    status: z.enum(["active", "archived"]),
    supply_mode: z.enum([
      "warehouse_stocked", "player_sourced_reserve", "made_to_order",
      "limited_release", "serialized_unique",
    ]).nullable(),
    unit_code: z.string(),
  })),
  license_classes: z.array(referenceBase.extend({
    description: z.string(),
    public_display_name: z.string(),
  })),
  price_schedules: z.array(z.object({
    audience_code: z.string(),
    code: z.string(),
    currency_code: z.string(),
    display_name: z.string(),
    id: z.guid(),
    priority: z.number().int(),
  })),
  units: z.array(referenceBase.extend({
    quantity_scale: z.number().int().nonnegative(),
    symbol: z.string().nullable(),
  })),
  warehouses: z.array(z.object({
    code: z.string(),
    display_name: z.string(),
    id: z.guid(),
    locations: z.array(z.object({
      code: z.string(),
      display_name: z.string(),
      id: z.guid(),
      location_type: z.enum(["receiving", "available", "quarantine", "damaged"]),
    })),
  })),
});

export type ConfigurationWorkspace = z.infer<typeof workspaceSchema>;

export type ConfigurationResult =
  | { ok: true; data: ConfigurationWorkspace }
  | { ok: false; code: "access_denied" | "invalid_response" | "query_failed" };

export async function getStaffConfigurationWorkspace(
  client: SupabaseClient,
): Promise<ConfigurationResult> {
  const { data, error } = await client.rpc("get_staff_configuration_workspace");
  if (error) {
    console.error(`[staff-configuration:workspace] ${error.message}`);
    return {
      ok: false,
      code: error.message.includes("permission_denied") ||
        error.message.includes("authentication_required")
        ? "access_denied"
        : "query_failed",
    };
  }
  const parsed = workspaceSchema.safeParse(data);
  if (!parsed.success) {
    console.error("[staff-configuration:workspace] Unexpected response shape.");
    return { ok: false, code: "invalid_response" };
  }
  return { ok: true, data: parsed.data };
}
