import { z } from "zod";

const codeSchema = z.string().trim().min(1).max(80).regex(/^[a-z0-9][a-z0-9_-]*$/);
const nameSchema = z.string().trim().min(1).max(200);
const reasonSchema = z.string().trim().min(1).max(500);

const createDealerFields = z.object({
  approvedPremisesPublic: z.string().trim().max(1000),
  dealerTypeCode: codeSchema,
  displayName: nameSchema,
  initialStatusCode: z.enum(["active", "internal-review"]),
  jurisdictionCode: codeSchema,
  legalName: nameSchema,
  partyTypeCode: codeSchema,
  privateNotes: z.string().trim().max(4000),
  publicDisclosureEnabled: z.boolean(),
  publicDisplayName: z.string().trim().max(200),
  publicNotes: z.string().trim().max(1000),
  reason: reasonSchema,
});

function requirePublicName(value: { publicDisclosureEnabled: boolean; publicDisplayName: string }, context: z.RefinementCtx) {
  if (value.publicDisclosureEnabled && !value.publicDisplayName) {
    context.addIssue({ code: "custom", message: "public_name_required", path: ["publicDisplayName"] });
  }
}

const createDealerSchema = createDealerFields.superRefine(requirePublicName);

const updateDealerSchema = createDealerFields.omit({
  dealerTypeCode: true,
  initialStatusCode: true,
  jurisdictionCode: true,
  partyTypeCode: true,
}).extend({
  dealerAuthorizationId: z.guid(),
  expectedVersion: z.coerce.number().int().positive().safe(),
}).superRefine(requirePublicName);

const changeDealerStatusSchema = z.object({
  dealerAuthorizationId: z.guid(),
  expectedVersion: z.coerce.number().int().positive().safe(),
  reason: reasonSchema,
  targetStatusCode: z.enum(["active", "suspended", "revoked"]),
});

export function readCreateDealerForm(formData: FormData) {
  return createDealerSchema.safeParse({
    approvedPremisesPublic: formData.get("approved_premises_public") ?? "",
    dealerTypeCode: formData.get("dealer_type_code"),
    displayName: formData.get("display_name"),
    initialStatusCode: formData.get("initial_status_code"),
    jurisdictionCode: formData.get("jurisdiction_code"),
    legalName: formData.get("legal_name"),
    partyTypeCode: formData.get("party_type_code"),
    privateNotes: formData.get("private_notes") ?? "",
    publicDisclosureEnabled: formData.get("public_disclosure_enabled") === "on",
    publicDisplayName: formData.get("public_display_name") ?? "",
    publicNotes: formData.get("public_notes") ?? "",
    reason: formData.get("reason"),
  });
}

export function readUpdateDealerForm(formData: FormData) {
  return updateDealerSchema.safeParse({
    approvedPremisesPublic: formData.get("approved_premises_public") ?? "",
    dealerAuthorizationId: formData.get("dealer_authorization_id"),
    displayName: formData.get("display_name"),
    expectedVersion: formData.get("expected_version"),
    legalName: formData.get("legal_name"),
    privateNotes: formData.get("private_notes") ?? "",
    publicDisclosureEnabled: formData.get("public_disclosure_enabled") === "on",
    publicDisplayName: formData.get("public_display_name") ?? "",
    publicNotes: formData.get("public_notes") ?? "",
    reason: formData.get("reason"),
  });
}

export function readChangeDealerStatusForm(formData: FormData) {
  return changeDealerStatusSchema.safeParse({
    dealerAuthorizationId: formData.get("dealer_authorization_id"),
    expectedVersion: formData.get("expected_version"),
    reason: formData.get("reason"),
    targetStatusCode: formData.get("target_status_code"),
  });
}
