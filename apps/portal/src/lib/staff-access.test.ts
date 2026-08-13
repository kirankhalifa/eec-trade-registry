import { describe, expect, it } from "vitest";

import { staffAccessStateSchema } from "./staff-access";

describe("staff access state", () => {
  it("distinguishes authentication awaiting approval from authority", () => {
    const parsed = staffAccessStateSchema.safeParse({
      access_class: null,
      display_name: "Pending Agent",
      last_attempted_at: "2026-08-13T12:00:00Z",
      request_id: "10000000-0000-4000-8000-000000000001",
      requested_at: "2026-08-13T12:00:00Z",
      review_reason: null,
      reviewed_at: null,
      state: "pending",
    });
    expect(parsed.success).toBe(true);
    if (parsed.success) expect(parsed.data.access_class).toBeNull();
  });

  it("requires an approved staff class for authorized state data", () => {
    expect(staffAccessStateSchema.safeParse({
      access_class: "business",
      display_name: "A business",
      last_attempted_at: null,
      request_id: null,
      requested_at: null,
      review_reason: null,
      reviewed_at: null,
      state: "authorized",
    }).success).toBe(false);
  });
});
