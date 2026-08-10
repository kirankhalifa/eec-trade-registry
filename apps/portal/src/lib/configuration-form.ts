import { z } from "zod";

const optionalText = (maximum: number) => z.string().trim().max(maximum);
const optionalGuid = z.preprocess(
  (value) => value === "" || value === null ? null : value,
  z.guid().nullable(),
);
const optionalNumber = z.preprocess(
  (value) => value === "" || value === null ? null : value,
  z.coerce.number().nonnegative().nullable(),
);
const optionalPositiveNumber = z.preprocess(
  (value) => value === "" || value === null ? null : value,
  z.coerce.number().positive().nullable(),
);
const optionalMoney = z.preprocess(
  (value) => value === "" || value === null ? null : value,
  z.coerce.number().int().nonnegative().safe().nullable(),
);
const reason = optionalText(500);

const quickItemSchema = z.object({
  availabilityProfileCode: z.string().trim().min(1).max(50),
  businessBulkReviewThreshold: optionalPositiveNumber,
  categoryCode: z.string().trim().min(1).max(50),
  controlProfileCode: z.string().trim().min(1).max(50),
  criticalLevel: optionalNumber,
  description: optionalText(4000),
  directIndividualAllowed: z.boolean(),
  directWeeklyLimit: optionalPositiveNumber,
  displayName: z.string().trim().min(1).max(200),
  itemCode: z.string().trim().max(32),
  minimumLevel: optionalNumber,
  openingQuantity: optionalPositiveNumber,
  openingStockLocationId: optionalGuid,
  priceAmountMinor: optionalMoney,
  priceScheduleId: optionalGuid,
  publish: z.boolean(),
  reason,
  requirementSummary: optionalText(1000),
  slug: z.string().trim().max(80),
  sourceReference: optionalText(200),
  supplyMode: z.enum([
    "warehouse_stocked", "player_sourced_reserve", "made_to_order",
    "limited_release", "serialized_unique",
  ]),
  surplusLevel: optionalNumber,
  targetLevel: optionalNumber,
  unitCode: z.string().trim().min(1).max(50),
}).superRefine((value, context) => {
  if (value.priceAmountMinor !== null && value.priceScheduleId === null) {
    context.addIssue({ code: "custom", path: ["priceScheduleId"], message: "Choose a price schedule." });
  }
  if (value.openingQuantity !== null && value.openingStockLocationId === null) {
    context.addIssue({ code: "custom", path: ["openingStockLocationId"], message: "Choose a stock location." });
  }
  if (value.openingQuantity !== null && ["player_sourced_reserve", "serialized_unique"].includes(value.supplyMode)) {
    context.addIssue({ code: "custom", path: ["openingQuantity"], message: "This supply mode cannot use a generic opening receipt." });
  }
});

export function readQuickItemForm(formData: FormData) {
  return quickItemSchema.safeParse({
    availabilityProfileCode: formData.get("availability_profile_code"),
    businessBulkReviewThreshold: formData.get("business_bulk_review_threshold"),
    categoryCode: formData.get("category_code"),
    controlProfileCode: formData.get("control_profile_code"),
    criticalLevel: formData.get("critical_level"),
    description: formData.get("description") ?? "",
    directIndividualAllowed: formData.get("direct_individual_allowed") === "on",
    directWeeklyLimit: formData.get("direct_weekly_limit"),
    displayName: formData.get("display_name"),
    itemCode: formData.get("item_code") ?? "",
    minimumLevel: formData.get("minimum_level"),
    openingQuantity: formData.get("opening_quantity"),
    openingStockLocationId: formData.get("opening_stock_location_id"),
    priceAmountMinor: formData.get("price_amount_minor"),
    priceScheduleId: formData.get("price_schedule_id"),
    publish: formData.get("publish") === "on",
    reason: formData.get("reason") ?? "",
    requirementSummary: formData.get("requirement_summary") ?? "",
    slug: formData.get("slug") ?? "",
    sourceReference: formData.get("source_reference") ?? "",
    supplyMode: formData.get("supply_mode"),
    surplusLevel: formData.get("surplus_level"),
    targetLevel: formData.get("target_level"),
    unitCode: formData.get("unit_code"),
  });
}

export function readQuickReceiptForm(formData: FormData) {
  return z.object({
    itemCode: z.string().trim().min(2).max(32),
    quantity: z.coerce.number().positive(),
    reason,
    sourceReference: optionalText(200),
    stockLocationId: z.guid(),
  }).safeParse({
    itemCode: formData.get("item_code"),
    quantity: formData.get("quantity"),
    reason: formData.get("reason") ?? "",
    sourceReference: formData.get("source_reference") ?? "",
    stockLocationId: formData.get("stock_location_id"),
  });
}

export function readConfigurationReferenceForm(formData: FormData) {
  return z.object({
    code: z.string().trim().regex(/^[a-z0-9][a-z0-9_-]{0,49}$/),
    description: optionalText(2000),
    displayName: z.string().trim().min(1).max(200),
    kind: z.enum(["item_category", "unit", "license_class", "endorsement", "availability_profile"]),
    publicDisplayName: optionalText(200),
    quantityScale: z.coerce.number().int().min(0).max(6),
    reason,
    sortOrder: z.coerce.number().int().safe(),
    symbol: optionalText(30),
  }).safeParse({
    code: formData.get("code"),
    description: formData.get("description") ?? "",
    displayName: formData.get("display_name"),
    kind: formData.get("kind"),
    publicDisplayName: formData.get("public_display_name") ?? "",
    quantityScale: formData.get("quantity_scale") || "0",
    reason: formData.get("reason") ?? "",
    sortOrder: formData.get("sort_order") || "0",
    symbol: formData.get("symbol") ?? "",
  });
}

export function readControlProfileForm(formData: FormData) {
  return z.object({
    code: z.string().trim().regex(/^[a-z0-9][a-z0-9_-]{0,49}$/),
    displayName: z.string().trim().min(1).max(200),
    publicDescription: z.string().trim().min(1).max(2000),
    reason,
    requiresSerialTracking: z.boolean(),
    requiresStaffReview: z.boolean(),
    requiresTransactionApproval: z.boolean(),
  }).safeParse({
    code: formData.get("code"),
    displayName: formData.get("display_name"),
    publicDescription: formData.get("public_description"),
    reason: formData.get("reason") ?? "",
    requiresSerialTracking: formData.get("requires_serial_tracking") === "on",
    requiresStaffReview: formData.get("requires_staff_review") === "on",
    requiresTransactionApproval: formData.get("requires_transaction_approval") === "on",
  });
}

export function readPublicTermsForm(formData: FormData) {
  return z.object({
    availabilityProfileCode: z.string().trim().min(1).max(50),
    bulkMinimum: optionalPositiveNumber,
    controlProfileCode: z.string().trim().min(1).max(50),
    itemId: z.guid(),
    orderIncrement: z.coerce.number().positive(),
    priceAction: z.enum(["keep", "set", "clear"]),
    priceAmountMinor: optionalMoney,
    priceScheduleId: optionalGuid,
    publicDescription: z.string().trim().min(1).max(4000),
    publicName: z.string().trim().min(1).max(200),
    publish: z.boolean(),
    reason,
    requirementSummary: z.string().trim().min(1).max(1000),
  }).superRefine((value, context) => {
    if (value.priceAction !== "keep" && value.priceScheduleId === null) {
      context.addIssue({ code: "custom", path: ["priceScheduleId"], message: "Choose a price schedule." });
    }
    if (value.priceAction === "set" && value.priceAmountMinor === null) {
      context.addIssue({ code: "custom", path: ["priceAmountMinor"], message: "Enter a price." });
    }
  }).safeParse({
    availabilityProfileCode: formData.get("availability_profile_code"),
    bulkMinimum: formData.get("bulk_minimum"),
    controlProfileCode: formData.get("control_profile_code"),
    itemId: formData.get("item_id"),
    orderIncrement: formData.get("order_increment") || "1",
    priceAction: formData.get("price_action"),
    priceAmountMinor: formData.get("price_amount_minor"),
    priceScheduleId: formData.get("price_schedule_id"),
    publicDescription: formData.get("public_description"),
    publicName: formData.get("public_name"),
    publish: formData.get("publish") === "on",
    reason: formData.get("reason") ?? "",
    requirementSummary: formData.get("requirement_summary"),
  });
}
