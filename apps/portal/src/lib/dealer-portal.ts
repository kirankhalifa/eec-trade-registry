import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";

const dealerAuthorizationSchema = z.object({
  dealer_type_label: z.string(),
  effective_from: z.string(),
  effective_until: z.string().nullable(),
  is_currently_authorized: z.boolean(),
  notice: z.string().nullable(),
  premises_label: z.string().nullable(),
  public_reference: z.string(),
  status_label: z.string(),
});

const dealerEndorsementSchema = z.object({
  effective_from: z.string(),
  expires_at: z.string().nullable(),
  label: z.string(),
});

const dealerLicenseSchema = z.object({
  effective_from: z.string(),
  endorsements: z.array(dealerEndorsementSchema),
  expires_at: z.string().nullable(),
  is_currently_authorized: z.boolean(),
  jurisdiction_label: z.string(),
  license_class_label: z.string(),
  notice: z.string().nullable(),
  public_conditions: z.array(z.string()),
  public_reference: z.string(),
  status_label: z.string(),
});

const dealerRepresentationSchema = z.object({
  dealer_authorizations: z.array(dealerAuthorizationSchema),
  jurisdiction_label: z.string().nullable(),
  licenses: z.array(dealerLicenseSchema),
  party_id: z.guid(),
  party_name: z.string(),
  representation_id: z.guid(),
  role_label: z.string(),
});

const dealerPortalOverviewSchema = z.object({
  actor_display_name: z.string(),
  generated_at: z.string(),
  representations: z.array(dealerRepresentationSchema).min(1),
});

export type DealerPortalOverview = z.infer<typeof dealerPortalOverviewSchema>;
export type DealerRepresentation = z.infer<typeof dealerRepresentationSchema>;

export type DealerPortalResult =
  | { ok: true; data: DealerPortalOverview }
  | { ok: false; code: "access_denied" | "invalid_response" | "query_failed" };

export async function getDealerPortalOverview(
  client: SupabaseClient,
): Promise<DealerPortalResult> {
  const { data, error } = await client.rpc("get_dealer_portal_overview");
  if (error) {
    console.error(`[dealer-portal:overview] ${error.code ?? "unknown"}`);
    const accessDenied =
      error.code === "42501" ||
      error.code === "28000" ||
      error.message.includes("dealer_access_denied") ||
      error.message.includes("dealer_authentication_required");
    return { ok: false, code: accessDenied ? "access_denied" : "query_failed" };
  }

  const parsed = dealerPortalOverviewSchema.safeParse(data);
  if (!parsed.success) {
    console.error("[dealer-portal:overview] Invalid Supabase response shape.");
    return { ok: false, code: "invalid_response" };
  }

  return { ok: true, data: parsed.data };
}
