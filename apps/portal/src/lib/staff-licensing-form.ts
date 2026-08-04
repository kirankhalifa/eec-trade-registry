import { z } from "zod";

const codeSchema = z
  .string()
  .trim()
  .min(1)
  .max(80)
  .regex(/^[a-z0-9][a-z0-9_-]*$/);

const reasonSchema = z.string().trim().min(1).max(500);

const issueLicenseSchema = z.object({
  dealerAuthorizationId: z.guid().nullable(),
  endorsementCodes: z.array(codeSchema).max(30),
  holderPartyId: z.guid(),
  initialStatusCode: z.enum(["active", "provisional"]),
  jurisdictionCode: codeSchema,
  licenseClassCode: codeSchema,
  privateNotes: z.string().trim().max(4000),
  publicDisclosureEnabled: z.boolean(),
  publicNotes: z.string().trim().max(1000),
  reason: reasonSchema,
});

const changeStatusSchema = z.object({
  expectedVersion: z.coerce.number().int().positive().safe(),
  licenseId: z.guid(),
  reason: reasonSchema,
  targetStatusCode: z.enum(["active", "suspended", "revoked", "surrendered"]),
});

const grantEndorsementSchema = z.object({
  endorsementCode: codeSchema,
  expectedLicenseVersion: z.coerce.number().int().positive().safe(),
  licenseId: z.guid(),
  publicDisclosureEnabled: z.boolean(),
  reason: reasonSchema,
});

const revokeEndorsementSchema = z.object({
  expectedLicenseVersion: z.coerce.number().int().positive().safe(),
  licenseEndorsementId: z.guid(),
  licenseId: z.guid(),
  reason: reasonSchema,
});

function optionalUuid(value: FormDataEntryValue | null): string | null {
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

export function readIssueLicenseForm(formData: FormData) {
  return issueLicenseSchema.safeParse({
    dealerAuthorizationId: optionalUuid(formData.get("dealer_authorization_id")),
    endorsementCodes: formData
      .getAll("endorsement_codes")
      .filter((value): value is string => typeof value === "string"),
    holderPartyId: formData.get("holder_party_id"),
    initialStatusCode: formData.get("initial_status_code"),
    jurisdictionCode: formData.get("jurisdiction_code"),
    licenseClassCode: formData.get("license_class_code"),
    privateNotes: formData.get("private_notes") ?? "",
    publicDisclosureEnabled: formData.get("public_disclosure_enabled") === "on",
    publicNotes: formData.get("public_notes") ?? "",
    reason: formData.get("reason"),
  });
}

export function readChangeLicenseStatusForm(formData: FormData) {
  return changeStatusSchema.safeParse({
    expectedVersion: formData.get("expected_version"),
    licenseId: formData.get("license_id"),
    reason: formData.get("reason"),
    targetStatusCode: formData.get("target_status_code"),
  });
}

export function readGrantEndorsementForm(formData: FormData) {
  return grantEndorsementSchema.safeParse({
    endorsementCode: formData.get("endorsement_code"),
    expectedLicenseVersion: formData.get("expected_license_version"),
    licenseId: formData.get("license_id"),
    publicDisclosureEnabled: formData.get("public_disclosure_enabled") === "on",
    reason: formData.get("reason"),
  });
}

export function readRevokeEndorsementForm(formData: FormData) {
  return revokeEndorsementSchema.safeParse({
    expectedLicenseVersion: formData.get("expected_license_version"),
    licenseEndorsementId: formData.get("license_endorsement_id"),
    licenseId: formData.get("license_id"),
    reason: formData.get("reason"),
  });
}
