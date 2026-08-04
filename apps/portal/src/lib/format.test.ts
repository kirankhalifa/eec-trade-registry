import { describe, expect, it } from "vitest";

import { formatMinorAmount, formatQuantity } from "@/lib/format";

describe("formatMinorAmount", () => {
  it("formats a configurable suffix symbol without assuming an ISO currency", () => {
    expect(formatMinorAmount(1250, "¤", "suffix", 0, "en-US")).toBe(
      "1,250 ¤",
    );
  });

  it("formats configured minor units", () => {
    expect(formatMinorAmount(1250, "$", "prefix", 2, "en-US")).toBe(
      "$12.50",
    );
  });

  it("rejects unsafe or unsupported values", () => {
    expect(formatMinorAmount(Number.MAX_VALUE, "$", "prefix", 2, "en-US")).toBeNull();
    expect(formatMinorAmount(100, "$", "prefix", 7, "en-US")).toBeNull();
  });
});

describe("formatQuantity", () => {
  it("formats a quantity with its configured unit symbol", () => {
    expect(formatQuantity(12.5, "crate", "en-US")).toBe("12.5 crate");
  });
});
