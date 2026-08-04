import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";

const licenseEndorsementSchema = z.object({
  code: z.string(),
  effective_from: z.string(),
  expires_at: z.string().nullable(),
  id: z.string().uuid(),
  label: z.string(),
  public_disclosure_enabled: z.boolean(),
  revoked_at: z.string().nullable(),
  version: z.number().int().positive().safe(),
});

const staffLicenseSchema = z.object({
  dealer_reference: z.string().nullable(),
  effective_from: z.string(),
  endorsements: z.array(licenseEndorsementSchema),
  expires_at: z.string().nullable(),
  holder_name: z.string(),
  id: z.string().uuid(),
  jurisdiction_code: z.string(),
  jurisdiction_label: z.string(),
  license_class_code: z.string(),
  license_class_label: z.string(),
  private_notes: z.string(),
  public_disclosure_enabled: z.boolean(),
  public_notes: z.string(),
  public_reference: z.string(),
  status_code: z.string(),
  status_label: z.string(),
  updated_at: z.string(),
  version: z.number().int().positive().safe(),
});

const optionSchema = z.object({
  code: z.string(),
  display_name: z.string(),
});

const partyOptionSchema = z.object({
  display_name: z.string(),
  id: z.string().uuid(),
  party_type: z.string(),
});

const dealerOptionSchema = z.object({
  id: z.string().uuid(),
  party_id: z.string().uuid(),
  public_reference: z.string(),
});

const licensingReferenceDataSchema = z.object({
  dealer_authorizations: z.array(dealerOptionSchema),
  endorsements: z.array(optionSchema),
  initial_statuses: z.array(optionSchema),
  jurisdictions: z.array(optionSchema),
  license_classes: z.array(optionSchema),
  parties: z.array(partyOptionSchema),
});

export type StaffLicense = z.infer<typeof staffLicenseSchema>;
export type StaffLicensingReferenceData = z.infer<
  typeof licensingReferenceDataSchema
>;

export type StaffLicensingResult<T> =
  | { ok: true; data: T }
  | {
      ok: false;
      code: "access_denied" | "invalid_response" | "query_failed";
    };

function errorCode(message: string): "access_denied" | "query_failed" {
  return message.includes("staff_permission_denied") ||
    message.includes("staff_authentication_required")
    ? "access_denied"
    : "query_failed";
}

function report(operation: string, message: string): void {
  console.error(`[staff-licensing:${operation}] ${message}`);
}

export async function getStaffLicenses(
  client: SupabaseClient,
  search?: string,
): Promise<StaffLicensingResult<StaffLicense[]>> {
  const { data, error } = await client.rpc("get_staff_license_queue", {
    p_search: search?.trim() || null,
  });
  if (error) {
    report("list", error.message);
    return { ok: false, code: errorCode(error.message) };
  }

  const parsed = z.array(staffLicenseSchema).safeParse(data);
  if (!parsed.success) {
    report("list", "Supabase returned an unexpected response shape.");
    return { ok: false, code: "invalid_response" };
  }
  return { ok: true, data: parsed.data };
}

export async function getStaffLicense(
  client: SupabaseClient,
  licenseId: string,
): Promise<StaffLicensingResult<StaffLicense | null>> {
  const { data, error } = await client.rpc("get_staff_license", {
    p_license_id: licenseId,
  });
  if (error) {
    report("detail", error.message);
    return { ok: false, code: errorCode(error.message) };
  }

  const candidate = Array.isArray(data) ? data[0] ?? null : null;
  if (candidate === null) {
    return { ok: true, data: null };
  }
  const parsed = staffLicenseSchema.safeParse(candidate);
  if (!parsed.success) {
    report("detail", "Supabase returned an unexpected response shape.");
    return { ok: false, code: "invalid_response" };
  }
  return { ok: true, data: parsed.data };
}

export async function getStaffLicensingReferenceData(
  client: SupabaseClient,
): Promise<StaffLicensingResult<StaffLicensingReferenceData>> {
  const { data, error } = await client.rpc(
    "get_staff_licensing_reference_data",
  );
  if (error) {
    report("references", error.message);
    return { ok: false, code: errorCode(error.message) };
  }

  const parsed = licensingReferenceDataSchema.safeParse(data);
  if (!parsed.success) {
    report("references", "Supabase returned an unexpected response shape.");
    return { ok: false, code: "invalid_response" };
  }
  return { ok: true, data: parsed.data };
}
