import { describe, expect, it } from "vitest";

import { readAccessReviewForm } from "./staff-access-form";

const requestId = "10000000-0000-4000-8000-000000000001";

describe("staff access review form", () => {
  it("accepts an explicit Agent approval with a reason", () => {
    const form = new FormData();
    form.set("access_request_id", requestId);
    form.set("expected_version", "1");
    form.set("decision", "approve");
    form.set("reason", "Known server agent; identity confirmed in Discord.");
    const parsed = readAccessReviewForm(form);
    expect(parsed.success).toBe(true);
    if (parsed.success) expect(parsed.data.decision).toBe("approve");
  });

  it("rejects a decision without an owner reason", () => {
    const form = new FormData();
    form.set("access_request_id", requestId);
    form.set("expected_version", "1");
    form.set("decision", "deny");
    form.set("reason", "");
    expect(readAccessReviewForm(form).success).toBe(false);
  });
});
