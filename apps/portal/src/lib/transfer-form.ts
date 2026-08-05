import { z } from "zod";

const reasonSchema = z.string().trim().min(1).max(500);

const createTransferSchema = z.object({
  destinationInventoryAccountId: z.guid(),
  quantity: z.coerce.number().positive().finite(),
  reason: reasonSchema,
  sourceInventoryAccountId: z.guid(),
}).refine(
  (value) => value.sourceInventoryAccountId !== value.destinationInventoryAccountId,
  { message: "transfer_accounts_must_differ" },
);

const transferCommandSchema = z.object({
  expectedVersion: z.coerce.number().int().positive().safe(),
  reason: reasonSchema,
  stockTransferId: z.guid(),
});

export function readCreateTransferForm(formData: FormData) {
  return createTransferSchema.safeParse({
    destinationInventoryAccountId: formData.get("destination_inventory_account_id"),
    quantity: formData.get("quantity"),
    reason: formData.get("reason"),
    sourceInventoryAccountId: formData.get("source_inventory_account_id"),
  });
}

export function readTransferCommandForm(formData: FormData) {
  return transferCommandSchema.safeParse({
    expectedVersion: formData.get("expected_version"),
    reason: formData.get("reason"),
    stockTransferId: formData.get("stock_transfer_id"),
  });
}
