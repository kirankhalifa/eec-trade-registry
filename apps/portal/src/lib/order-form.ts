import { z } from "zod";

const reasonSchema = z.string().trim().min(1).max(500);

const orderLineInputSchema = z.object({
  itemId: z.guid(),
  quantity: z.coerce.number().positive(),
});

const submitOrderSchema = z
  .object({
    dealerAuthorizationId: z.guid(),
    dealerNotes: z.string().trim().max(2000),
    fulfillmentMode: z.enum(["collection", "delivery", "consignment"]),
    licenseId: z.guid().nullable(),
    lines: z.array(orderLineInputSchema).min(1).max(10),
    orderingPartyId: z.guid(),
    reason: reasonSchema,
  })
  .superRefine((value, context) => {
    const itemIds = value.lines.map((line) => line.itemId);
    if (new Set(itemIds).size !== itemIds.length) {
      context.addIssue({
        code: "custom",
        message: "Duplicate order items are not allowed.",
        path: ["lines"],
      });
    }
  });

const cancelOrderSchema = z.object({
  expectedVersion: z.coerce.number().int().positive().safe(),
  orderId: z.guid(),
  reason: reasonSchema,
});

const reviewOrderLineSchema = z.object({
  approvedQuantity: z.coerce.number().positive().nullable(),
  decision: z.enum(["approve", "awaiting_stock", "deny"]),
  expectedOrderVersion: z.coerce.number().int().positive().safe(),
  orderId: z.guid(),
  orderLineId: z.guid(),
  reason: reasonSchema,
  unitPriceMinor: z.coerce.number().int().nonnegative().safe().nullable(),
});

const priceOrderLineSchema = z.object({
  expectedOrderVersion: z.coerce.number().int().positive().safe(),
  orderId: z.guid(),
  orderLineId: z.guid(),
  reason: reasonSchema,
  unitPriceMinor: z.coerce.number().int().nonnegative().safe().nullable(),
});

function optionalString(value: FormDataEntryValue | null): string | null {
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

export function readSubmitOrderForm(formData: FormData) {
  const itemIds = formData.getAll("item_ids");
  const quantities = formData.getAll("quantities");
  const lines = itemIds.flatMap((itemId, index) => {
    const quantity = quantities[index];
    if (
      typeof itemId !== "string" ||
      !itemId.trim() ||
      typeof quantity !== "string" ||
      !quantity.trim()
    ) {
      return [];
    }
    return [{ itemId: itemId.trim(), quantity }];
  });

  return submitOrderSchema.safeParse({
    dealerAuthorizationId: formData.get("dealer_authorization_id"),
    dealerNotes: formData.get("dealer_notes") ?? "",
    fulfillmentMode: formData.get("fulfillment_mode"),
    licenseId: optionalString(formData.get("license_id")),
    lines,
    orderingPartyId: formData.get("ordering_party_id"),
    reason: formData.get("reason"),
  });
}

export function readCancelOrderForm(formData: FormData) {
  return cancelOrderSchema.safeParse({
    expectedVersion: formData.get("expected_version"),
    orderId: formData.get("order_id"),
    reason: formData.get("reason"),
  });
}

export function readReviewOrderLineForm(formData: FormData) {
  return reviewOrderLineSchema.safeParse({
    approvedQuantity: optionalString(formData.get("approved_quantity")),
    decision: formData.get("decision"),
    expectedOrderVersion: formData.get("expected_order_version"),
    orderId: formData.get("order_id"),
    orderLineId: formData.get("order_line_id"),
    reason: formData.get("reason"),
    unitPriceMinor: optionalString(formData.get("unit_price_minor")),
  });
}

export function readPriceOrderLineForm(formData: FormData) {
  return priceOrderLineSchema.safeParse({
    expectedOrderVersion: formData.get("expected_order_version"),
    orderId: formData.get("order_id"),
    orderLineId: formData.get("order_line_id"),
    reason: formData.get("reason"),
    unitPriceMinor: optionalString(formData.get("unit_price_minor")),
  });
}
