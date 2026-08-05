import { describe, expect, it } from "vitest";

import { hasValidBearerSecret } from "./integration-auth";

describe("integration cron authorization", () => {
  it("accepts only an exact bearer secret", () => {
    expect(hasValidBearerSecret("Bearer correct-secret-value", "correct-secret-value")).toBe(true);
    expect(hasValidBearerSecret("Bearer wrong-secret-value", "correct-secret-value")).toBe(false);
    expect(hasValidBearerSecret("Basic correct-secret-value", "correct-secret-value")).toBe(false);
    expect(hasValidBearerSecret(null, "correct-secret-value")).toBe(false);
  });
});
