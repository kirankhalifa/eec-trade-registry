import { z } from "zod";

const reviewSchema = z.object({
  accessRequestId: z.guid(),
  decision: z.enum(["approve", "deny", "block"]),
  expectedVersion: z.coerce.number().int().positive(),
  reason: z.string().trim().min(1).max(500),
});

export function readAccessReviewForm(formData: FormData) {
  return reviewSchema.safeParse({
    accessRequestId: formData.get("access_request_id"),
    decision: formData.get("decision"),
    expectedVersion: formData.get("expected_version"),
    reason: formData.get("reason"),
  });
}
