import { z } from "zod";

const reason = z.string().trim().min(1).max(500);
const condition = z.enum(["excellent", "good", "fair", "damaged", "unknown"]);
const commandBase = z.object({
  assetId: z.guid(), expectedVersion: z.coerce.number().int().positive().safe(), reason,
});

const registerSchema = z.object({
  conditionCode: condition,
  itemId: z.guid(),
  provenanceSummary: z.string().trim().max(4000),
  reason,
  serialMarking: z.string().trim().max(200),
  stockLocationId: z.guid(),
});
const reserveSchema = commandBase.extend({ orderLineId: z.guid() });
const releaseSchema = z.object({
  assetReservationId: z.guid(), expectedVersion: z.coerce.number().int().positive().safe(), reason,
});
const custodySchema = commandBase.extend({
  conditionCode: condition,
  destination: z.string().regex(/^(party:[0-9a-f-]{36}|location:[0-9a-f-]{36}:[0-9a-f-]{36})$/i),
});
const inspectionSchema = commandBase.extend({
  conditionCode: condition,
  nextDueDate: z.string().trim().regex(/^\d{4}-\d{2}-\d{2}$/).or(z.literal("")),
  observation: z.string().trim().min(1).max(4000),
});
const lifecycleSchema = commandBase.extend({
  status: z.enum(["available", "missing", "damaged", "seized", "retired", "destroyed"]),
});

export function readRegisterAssetForm(formData: FormData) {
  return registerSchema.safeParse({
    conditionCode: formData.get("condition_code"), itemId: formData.get("item_id"),
    provenanceSummary: formData.get("provenance_summary"), reason: formData.get("reason"),
    serialMarking: formData.get("serial_marking"), stockLocationId: formData.get("stock_location_id"),
  });
}
function command(formData: FormData) {
  return {
    assetId: formData.get("asset_id"), expectedVersion: formData.get("expected_version"),
    reason: formData.get("reason"),
  };
}
export function readReserveAssetForm(formData: FormData) {
  return reserveSchema.safeParse({ ...command(formData), orderLineId: formData.get("order_line_id") });
}
export function readReleaseAssetReservationForm(formData: FormData) {
  return releaseSchema.safeParse({
    assetReservationId: formData.get("asset_reservation_id"),
    expectedVersion: formData.get("expected_version"), reason: formData.get("reason"),
  });
}
export function readTransferAssetForm(formData: FormData) {
  return custodySchema.safeParse({
    ...command(formData), conditionCode: formData.get("condition_code"),
    destination: formData.get("destination"),
  });
}
export function readInspectAssetForm(formData: FormData) {
  return inspectionSchema.safeParse({
    ...command(formData), conditionCode: formData.get("condition_code"),
    nextDueDate: formData.get("next_due_date"), observation: formData.get("observation"),
  });
}
export function readAssetLifecycleForm(formData: FormData) {
  return lifecycleSchema.safeParse({ ...command(formData), status: formData.get("status") });
}
