import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";

const dealerSchema = z.object({
  approved_premises_public: z.string().nullable(),
  dealer_type_code: z.string(),
  dealer_type_label: z.string(),
  display_name: z.string(),
  effective_from: z.string(),
  effective_until: z.string().nullable(),
  id: z.guid(),
  jurisdiction_code: z.string(),
  jurisdiction_label: z.string(),
  legal_name: z.string(),
  party_id: z.guid(),
  party_type_code: z.string(),
  party_type_label: z.string(),
  private_notes: z.string(),
  public_disclosure_enabled: z.boolean(),
  public_display_name: z.string().nullable(),
  public_notes: z.string(),
  public_reference: z.string(),
  status_code: z.string(),
  status_label: z.string(),
  updated_at: z.string(),
  version: z.number().int().positive().safe(),
});

const optionSchema = z.object({ code: z.string(), display_name: z.string() });
const referenceSchema = z.object({
  dealer_types: z.array(optionSchema),
  initial_statuses: z.array(optionSchema),
  jurisdictions: z.array(optionSchema),
  party_types: z.array(optionSchema),
});

export type StaffDealer = z.infer<typeof dealerSchema>;
export type StaffDealerReferenceData = z.infer<typeof referenceSchema>;
export type StaffDealerResult<T> =
  | { ok: true; data: T }
  | { ok: false; code: "access_denied" | "invalid_response" | "query_failed" };

function errorCode(message: string): "access_denied" | "query_failed" {
  return message.includes("staff_permission_denied") || message.includes("staff_authentication_required")
    ? "access_denied"
    : "query_failed";
}

function report(operation: string, message: string) {
  console.error(`[staff-dealers:${operation}] ${message}`);
}

export async function getStaffDealers(client: SupabaseClient, search?: string): Promise<StaffDealerResult<StaffDealer[]>> {
  const { data, error } = await client.rpc("get_staff_dealer_queue", { p_search: search?.trim() || null });
  if (error) { report("list", error.message); return { ok: false, code: errorCode(error.message) }; }
  const parsed = z.array(dealerSchema).safeParse(data);
  if (!parsed.success) { report("list", "Supabase returned an unexpected response shape."); return { ok: false, code: "invalid_response" }; }
  return { ok: true, data: parsed.data };
}

export async function getStaffDealer(client: SupabaseClient, dealerId: string): Promise<StaffDealerResult<StaffDealer | null>> {
  const { data, error } = await client.rpc("get_staff_dealer", { p_dealer_authorization_id: dealerId });
  if (error) { report("detail", error.message); return { ok: false, code: errorCode(error.message) }; }
  const candidate = Array.isArray(data) ? data[0] ?? null : null;
  if (candidate === null) return { ok: true, data: null };
  const parsed = dealerSchema.safeParse(candidate);
  if (!parsed.success) { report("detail", "Supabase returned an unexpected response shape."); return { ok: false, code: "invalid_response" }; }
  return { ok: true, data: parsed.data };
}

export async function getStaffDealerReferenceData(client: SupabaseClient): Promise<StaffDealerResult<StaffDealerReferenceData>> {
  const { data, error } = await client.rpc("get_staff_dealer_reference_data");
  if (error) { report("references", error.message); return { ok: false, code: errorCode(error.message) }; }
  const parsed = referenceSchema.safeParse(data);
  if (!parsed.success) { report("references", "Supabase returned an unexpected response shape."); return { ok: false, code: "invalid_response" }; }
  return { ok: true, data: parsed.data };
}
