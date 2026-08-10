import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";

const option = z.object({ id: z.guid(), label: z.string() });
const launchWorkspaceSchema = z.object({
  applications: z.array(z.object({
    applicant_name: z.string(), class_name: z.string(), contact_label: z.string(),
    existing_license_reference: z.string().nullable(), id: z.guid(), jurisdiction_name: z.string(),
    reference: z.string(), statement: z.string(), status: z.string(), submitted_at: z.string(),
    type: z.enum(["new", "renewal"]), version: z.number().int().positive(),
  })),
  businesses: z.array(z.object({
    dealer_authorization_id: z.guid(), dealer_reference: z.string(), jurisdiction_id: z.guid(),
    licenses: z.array(z.object({ class: z.string(), id: z.guid(), reference: z.string() })),
    party_id: z.guid(), party_name: z.string(),
  })),
  capabilities: z.object({
    can_create_order: z.boolean(), can_fulfill_asset: z.boolean(),
    can_generate_documents: z.boolean(), can_manage_finance: z.boolean(),
    can_manage_pricing: z.boolean(), can_review_applications: z.boolean(),
  }),
  consignment_agreements: z.array(option),
  direct_customers: z.array(z.object({ name: z.string(), party_id: z.guid(), reference: z.string() })),
  document_sources: z.object({
    fulfillments: z.array(option).default([]), licenses: z.array(option).default([]),
    orders: z.array(option).default([]), settlements: z.array(option).default([]),
  }),
  items: z.array(z.object({
    code: z.string(), direct_allowed: z.boolean(), direct_weekly_limit: z.coerce.number().positive().nullable(),
    id: z.guid(), name: z.string(), unit: z.string(),
  })),
  jurisdictions: z.array(z.object({ code: z.string(), id: z.guid(), label: z.string() })),
  parties: z.array(option),
  price_schedules: z.array(z.object({ audience: z.string(), id: z.guid(), label: z.string() })),
  price_targets: z.object({
    dealer_types: z.array(option).default([]), jurisdictions: z.array(option).default([]),
    license_classes: z.array(option).default([]), parties: z.array(option).default([]),
  }),
  settlement_candidates: z.array(z.object({
    agreement_reference: z.string(), quantity_sold: z.coerce.number().positive(), report_id: z.guid(), report_reference: z.string(),
  })),
  settlements: z.array(z.object({
    commission: z.number().int().nonnegative(), currency: z.string(), gross: z.number().int().nonnegative(),
    id: z.guid(), owner_amount: z.number().int().nonnegative(), reference: z.string(), status: z.string(),
    version: z.number().int().positive(),
  })),
  unique_reservations: z.array(z.object({
    asset_id: z.guid(), asset_reference: z.string(), asset_version: z.number().int().positive(),
    customer_name: z.string(), expires_at: z.string(), order_reference: z.string(), reservation_id: z.guid(),
    reservation_reference: z.string(), reservation_version: z.number().int().positive(),
  })),
});

export type LaunchWorkspace = z.infer<typeof launchWorkspaceSchema>;

export async function getLaunchWorkspace(client: SupabaseClient) {
  const { data, error } = await client.rpc("get_staff_launch_workspace");
  if (error) {
    console.error(`[launch-workspace] ${error.message}`);
    return { ok: false as const, denied: error.message.includes("permission_denied") };
  }
  const parsed = launchWorkspaceSchema.safeParse(data);
  if (!parsed.success) {
    console.error("[launch-workspace] Unexpected authoritative response.", parsed.error.issues);
    return { ok: false as const, denied: false };
  }
  return { ok: true as const, data: parsed.data };
}
