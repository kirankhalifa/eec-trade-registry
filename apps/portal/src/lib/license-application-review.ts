import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";

const applicationSchema = z.object({
  applicant_name: z.string(),
  class_name: z.string(),
  contact_label: z.string(),
  existing_license_reference: z.string().nullable(),
  id: z.guid(),
  issued_license_reference: z.string().nullable(),
  jurisdiction_name: z.string(),
  reference: z.string(),
  requested_endorsements: z.array(z.object({ code: z.string(), label: z.string() })),
  review_reason: z.string().nullable(),
  reviewed_at: z.string().nullable(),
  statement: z.string(),
  status: z.enum(["submitted", "under_review", "issued", "renewed", "denied", "withdrawn"]),
  submitted_at: z.string(),
  type: z.enum(["new", "renewal"]),
  version: z.number().int().positive(),
});

const workspaceSchema = z.object({
  applications: z.array(applicationSchema),
  generated_at: z.string(),
  parties: z.array(z.object({ id: z.guid(), name: z.string(), type: z.string() })),
});

export type LicenseApplicationReviewWorkspace = z.infer<typeof workspaceSchema>;

export function parseLicenseApplicationReviewWorkspace(data: unknown) {
  return workspaceSchema.safeParse(data);
}

export async function getLicenseApplicationReviewWorkspace(client: SupabaseClient) {
  const { data, error } = await client.rpc("get_staff_license_application_review_workspace");
  if (error) {
    console.error(`[license-applications:workspace] ${error.code ?? "unknown"}`);
    return {
      ok: false as const,
      denied: error.code === "42501" || error.message.includes("permission_denied"),
    };
  }
  const parsed = parseLicenseApplicationReviewWorkspace(data);
  if (!parsed.success) {
    console.error("[license-applications:workspace] Unexpected authoritative response.", parsed.error.issues);
    return { ok: false as const, denied: false };
  }
  return { ok: true as const, data: parsed.data };
}
