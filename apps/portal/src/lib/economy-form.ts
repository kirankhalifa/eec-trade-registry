import { z } from "zod";

const reason = z.string().trim().min(1).max(500);
const optionalNumber = z.preprocess((value) => value === "" || value === null ? null : value,
  z.coerce.number().nonnegative().nullable());
const optionalPositiveNumber = z.preprocess((value) => value === "" || value === null ? null : value,
  z.coerce.number().positive().nullable());
const optionalDate = z.preprocess((value) => value === "" || value === null ? null : value,
  z.string().datetime({ local: true }).nullable());

export function readSupplyPolicyForm(formData: FormData) {
  return z.object({
    adminReceiptAllowed: z.coerce.boolean(),
    businessBulkReviewThreshold: optionalPositiveNumber,
    criticalLevel: optionalNumber,
    directIndividualAllowed: z.coerce.boolean(),
    directWeeklyLimit: optionalPositiveNumber,
    expectedVersion: z.coerce.number().int().positive().safe(),
    itemId: z.guid(),
    minimumLevel: optionalNumber,
    playerSourcedOnly: z.coerce.boolean(),
    procurementEnabled: z.coerce.boolean(),
    reason,
    supplyMode: z.enum(["warehouse_stocked", "player_sourced_reserve", "made_to_order", "limited_release", "serialized_unique"]),
    surplusLevel: optionalNumber,
    targetLevel: optionalNumber,
  }).safeParse({
    adminReceiptAllowed: formData.get("admin_receipt_allowed") === "on",
    businessBulkReviewThreshold: formData.get("business_bulk_review_threshold"),
    criticalLevel: formData.get("critical_level"),
    directIndividualAllowed: formData.get("direct_individual_allowed") === "on",
    directWeeklyLimit: formData.get("direct_weekly_limit"),
    expectedVersion: formData.get("expected_version"), itemId: formData.get("item_id"),
    minimumLevel: formData.get("minimum_level"),
    playerSourcedOnly: formData.get("player_sourced_only") === "on",
    procurementEnabled: formData.get("procurement_enabled") === "on",
    reason: formData.get("reason"), supplyMode: formData.get("supply_mode"),
    surplusLevel: formData.get("surplus_level"), targetLevel: formData.get("target_level"),
  });
}

export function readSupplierForm(formData: FormData) {
  return z.object({
    displayName: z.string().trim().min(1).max(200), jurisdictionId: z.guid(),
    legalName: z.string().trim().min(1).max(300), notes: z.string().trim().max(2000),
    partyTypeCode: z.string().trim().min(1).max(50), reason,
  }).safeParse({
    displayName: formData.get("display_name") || formData.get("legal_name"), jurisdictionId: formData.get("jurisdiction_id"),
    legalName: formData.get("legal_name"), notes: formData.get("notes") ?? "",
    partyTypeCode: formData.get("party_type_code"), reason: formData.get("reason"),
  });
}

export function readOfferForm(formData: FormData) {
  return z.object({
    amountMinor: z.coerce.number().int().positive().safe(), currencyId: z.guid(),
    effectiveFrom: z.string().datetime({ local: true }), effectiveUntil: optionalDate,
    itemId: z.guid(), minimumQuantity: z.coerce.number().positive(),
    notes: z.string().trim().max(2000), reason, staffReviewQuantity: optionalPositiveNumber,
  }).safeParse({
    amountMinor: formData.get("amount_minor"), currencyId: formData.get("currency_id"),
    effectiveFrom: formData.get("effective_from"), effectiveUntil: formData.get("effective_until"),
    itemId: formData.get("item_id"), minimumQuantity: formData.get("minimum_quantity"),
    notes: formData.get("notes") ?? "", reason: formData.get("reason"),
    staffReviewQuantity: formData.get("staff_review_quantity"),
  });
}

export function readDeliveryForm(formData: FormData) {
  return z.object({
    offerId: z.guid(), quantity: z.coerce.number().positive(), reason,
    stockLocationId: z.guid(), supplierId: z.guid(),
  }).safeParse({
    offerId: formData.get("offer_id"), quantity: formData.get("quantity"),
    reason: formData.get("reason"), stockLocationId: formData.get("stock_location_id"),
    supplierId: formData.get("supplier_id"),
  });
}

export function readSettlementForm(formData: FormData) {
  return z.object({
    deliveryId: z.guid(), expectedVersion: z.coerce.number().int().positive().safe(),
    reason, settlementReference: z.string().trim().min(1).max(200),
  }).safeParse({
    deliveryId: formData.get("delivery_id"), expectedVersion: formData.get("expected_version"),
    reason: formData.get("reason"), settlementReference: formData.get("settlement_reference"),
  });
}
