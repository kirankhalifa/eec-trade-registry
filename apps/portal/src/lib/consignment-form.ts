import { z } from "zod";

const reason = z.string().trim().min(1).max(500);
const quantity = z.coerce.number().min(0).max(999_999_999_999);
const positiveQuantity = quantity.refine((value) => value > 0);
const command = z.object({
  id: z.guid(),
  expectedVersion: z.coerce.number().int().positive().safe(),
  reason,
});
const agreementSchema = z.object({
  ownerPartyId: z.guid(),
  consigneePartyId: z.guid(),
  jurisdictionId: z.guid(),
  effectiveFrom: z.string().datetime({ offset: true }),
  effectiveUntil: z.string().datetime({ offset: true }).nullable(),
  termsSummary: z.string().trim().max(4000),
  reason,
});
const agreementStatusSchema = command.extend({
  status: z.enum(["active", "suspended", "closed"]),
});
const issueSchema = z.object({
  agreementId: z.guid(),
  sourceInventoryAccountId: z.guid(),
  quantity: positiveQuantity,
  reason,
});
const reviewSchema = command.extend({
  returnInventoryAccountId: z.guid().nullable(),
});
const reportSchema = z.object({
  consignmentIssueId: z.guid(),
  quantitySold: quantity,
  quantityReturned: quantity,
  quantityLost: quantity,
  quantityDamaged: quantity,
  observedOnHand: quantity,
  reportNotes: z.string().trim().max(4000),
  reason,
});

function nullable(value: FormDataEntryValue | null) {
  return typeof value === "string" && value.trim() ? value : null;
}
function timestamp(value: FormDataEntryValue | null) {
  if (typeof value !== "string" || !value.trim()) return value;
  const parsed = new Date(value);
  return Number.isNaN(parsed.valueOf()) ? value : parsed.toISOString();
}
function commandFields(formData: FormData) {
  return {
    id: formData.get("id"),
    expectedVersion: formData.get("expected_version"),
    reason: formData.get("reason"),
  };
}

export function readCreateConsignmentAgreementForm(formData: FormData) {
  return agreementSchema.safeParse({
    ownerPartyId: formData.get("owner_party_id"),
    consigneePartyId: formData.get("consignee_party_id"),
    jurisdictionId: formData.get("jurisdiction_id"),
    effectiveFrom: timestamp(formData.get("effective_from")),
    effectiveUntil: nullable(formData.get("effective_until"))
      ? timestamp(formData.get("effective_until"))
      : null,
    termsSummary: formData.get("terms_summary"),
    reason: formData.get("reason"),
  });
}
export function readConsignmentAgreementStatusForm(formData: FormData) {
  return agreementStatusSchema.safeParse({ ...commandFields(formData), status: formData.get("status") });
}
export function readIssueConsignmentForm(formData: FormData) {
  return issueSchema.safeParse({
    agreementId: formData.get("agreement_id"),
    sourceInventoryAccountId: formData.get("source_inventory_account_id"),
    quantity: formData.get("quantity"),
    reason: formData.get("reason"),
  });
}
export function readReviewConsignmentReportForm(formData: FormData) {
  return reviewSchema.safeParse({
    ...commandFields(formData),
    returnInventoryAccountId: nullable(formData.get("return_inventory_account_id")),
  });
}
export function readDealerConsignmentReportForm(formData: FormData) {
  return reportSchema.safeParse({
    consignmentIssueId: formData.get("consignment_issue_id"),
    quantitySold: formData.get("quantity_sold"),
    quantityReturned: formData.get("quantity_returned"),
    quantityLost: formData.get("quantity_lost"),
    quantityDamaged: formData.get("quantity_damaged"),
    observedOnHand: formData.get("observed_on_hand"),
    reportNotes: formData.get("report_notes"),
    reason: formData.get("reason"),
  });
}
