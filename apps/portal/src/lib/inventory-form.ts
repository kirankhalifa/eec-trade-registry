import { z } from "zod";

const reasonSchema = z.string().trim().min(1).max(500);

const receiptSchema = z.object({
  itemId: z.guid(),
  quantity: z.coerce.number().positive(),
  reason: reasonSchema,
  sourceReference: z.string().trim().min(1).max(200),
  stockLocationId: z.guid(),
});

const reservationSchema = z.object({
  inventoryAccountId: z.guid(),
  orderLineId: z.guid(),
  quantity: z.coerce.number().positive(),
  reason: reasonSchema,
});

const reservationMutationSchema = z.object({
  expectedVersion: z.coerce.number().int().positive().safe(),
  reason: reasonSchema,
  reservationId: z.guid(),
});

const extensionSchema = reservationMutationSchema.extend({
  expiresAt: z
    .string()
    .trim()
    .min(1)
    .transform((value, context) => {
      const date = new Date(/[zZ]|[+-]\d{2}:\d{2}$/.test(value) ? value : `${value}Z`);
      if (Number.isNaN(date.valueOf())) {
        context.addIssue({ code: "custom", message: "Invalid expiration." });
        return z.NEVER;
      }
      return date.toISOString();
    }),
});

const reversalSchema = z.object({
  inventoryTransactionId: z.guid(),
  reason: reasonSchema,
});

export function readInventoryReceiptForm(formData: FormData) {
  return receiptSchema.safeParse({
    itemId: formData.get("item_id"),
    quantity: formData.get("quantity"),
    reason: formData.get("reason"),
    sourceReference: formData.get("source_reference"),
    stockLocationId: formData.get("stock_location_id"),
  });
}

export function readCreateReservationForm(formData: FormData) {
  return reservationSchema.safeParse({
    inventoryAccountId: formData.get("inventory_account_id"),
    orderLineId: formData.get("order_line_id"),
    quantity: formData.get("quantity"),
    reason: formData.get("reason"),
  });
}

export function readReservationMutationForm(formData: FormData) {
  return reservationMutationSchema.safeParse({
    expectedVersion: formData.get("expected_version"),
    reason: formData.get("reason"),
    reservationId: formData.get("reservation_id"),
  });
}

export function readExtendReservationForm(formData: FormData) {
  return extensionSchema.safeParse({
    expectedVersion: formData.get("expected_version"),
    expiresAt: formData.get("expires_at"),
    reason: formData.get("reason"),
    reservationId: formData.get("reservation_id"),
  });
}

export function readReverseInventoryForm(formData: FormData) {
  return reversalSchema.safeParse({
    inventoryTransactionId: formData.get("inventory_transaction_id"),
    reason: formData.get("reason"),
  });
}
