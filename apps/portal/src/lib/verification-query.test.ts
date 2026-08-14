import { describe, expect, it } from "vitest";

import {
  inferVerificationKind,
  normalizeVerificationReference,
  parseVerificationReference,
} from "@/lib/verification-query";

describe("public verification reference normalization", () => {
  it("normalizes case and whitespace without imposing a numbering format", () => {
    expect(normalizeVerificationReference("  lic-demo  4q2m ")).toBe(
      "LIC-DEMO 4Q2M",
    );
  });

  it("uses the first query value and treats blanks as no lookup", () => {
    expect(
      parseVerificationReference({ reference: [" dlr-demo-a7k9 ", "ignored"] }),
    ).toBe("DLR-DEMO-A7K9");
    expect(parseVerificationReference({ reference: "   " })).toBeNull();
  });

  it("limits input to the database contract", () => {
    expect(normalizeVerificationReference("x".repeat(200))).toHaveLength(128);
  });
});

describe("verification routing", () => {
  it("routes supported references by their printed prefix", () => {
    expect(inferVerificationKind("DLR-ABC-1234")).toBe("dealer");
    expect(inferVerificationKind("LIC-ABC-1234")).toBe("license");
    expect(inferVerificationKind("EEC-DLR-1001-ABCDEF1234")).toBe("dealer");
    expect(inferVerificationKind("EEC-LIC-1001-ABCDEF1234")).toBe("license");
    expect(inferVerificationKind("EEC-ORD-1001")).toBeNull();
  });
});
