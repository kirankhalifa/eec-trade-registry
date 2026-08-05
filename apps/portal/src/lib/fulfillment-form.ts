import { z } from "zod";

const reasonSchema = z.string().trim().min(1).max(500);

const fulfillReservationSchema = z.object({
  expectedVersion: z.coerce.number().int().positive().safe(),
  reason: reasonSchema,
  reservationId: z.guid(),
});

const reverseFulfillmentSchema = z.object({
  expectedVersion: z.coerce.number().int().positive().safe(),
  fulfillmentId: z.guid(),
  reason: reasonSchema,
});

export function readFulfillReservationForm(formData: FormData) {
  return fulfillReservationSchema.safeParse({
    expectedVersion: formData.get("expected_version"),
    reason: formData.get("reason"),
    reservationId: formData.get("reservation_id"),
  });
}

export function readReverseFulfillmentForm(formData: FormData) {
  return reverseFulfillmentSchema.safeParse({
    expectedVersion: formData.get("expected_version"),
    fulfillmentId: formData.get("fulfillment_id"),
    reason: formData.get("reason"),
  });
}
