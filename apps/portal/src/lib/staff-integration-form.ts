import { z } from "zod";

const reasonSchema = z.string().trim().min(1).max(500);

const configureDestinationSchema = z
  .object({
    active: z.boolean(),
    destinationId: z.guid(),
    expectedVersion: z.coerce.number().int().positive().safe(),
    externalReference: z.string().trim().max(256),
    reason: reasonSchema,
  })
  .refine((value) => !value.active || value.externalReference.length > 0, {
    message: "An active destination requires an external reference.",
    path: ["externalReference"],
  });

const setDefinitionStatusSchema = z.object({
  active: z.boolean(),
  definitionId: z.guid(),
  expectedVersion: z.coerce.number().int().positive().safe(),
  reason: reasonSchema,
});

const queueExportSchema = z.object({ definitionId: z.guid(), reason: reasonSchema });
const replayExportSchema = z.object({ exportRunId: z.guid(), reason: reasonSchema });
const replayDeliverySchema = z.object({ deliveryId: z.guid(), reason: reasonSchema });

export function readConfigureDestinationForm(formData: FormData) {
  return configureDestinationSchema.safeParse({
    active: formData.get("active") === "on",
    destinationId: formData.get("destination_id"),
    expectedVersion: formData.get("expected_version"),
    externalReference: formData.get("external_reference") ?? "",
    reason: formData.get("reason"),
  });
}

export function readSetDefinitionStatusForm(formData: FormData) {
  return setDefinitionStatusSchema.safeParse({
    active: formData.get("active") === "on",
    definitionId: formData.get("definition_id"),
    expectedVersion: formData.get("expected_version"),
    reason: formData.get("reason"),
  });
}

export function readQueueExportForm(formData: FormData) {
  return queueExportSchema.safeParse({
    definitionId: formData.get("definition_id"),
    reason: formData.get("reason"),
  });
}

export function readReplayExportForm(formData: FormData) {
  return replayExportSchema.safeParse({
    exportRunId: formData.get("export_run_id"),
    reason: formData.get("reason"),
  });
}

export function readReplayDeliveryForm(formData: FormData) {
  return replayDeliverySchema.safeParse({
    deliveryId: formData.get("delivery_id"),
    reason: formData.get("reason"),
  });
}
