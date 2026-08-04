import { describe, expect, it } from "vitest";

import {
  normalizeCategory,
  normalizeSearch,
  parseCatalogueQuery,
} from "@/lib/query";

describe("catalogue query normalization", () => {
  it("normalizes whitespace and arrays", () => {
    expect(
      parseCatalogueQuery({ q: ["  brass   lantern  "], category: "TOOLS" }),
    ).toEqual({ search: "brass lantern", category: "tools" });
  });

  it("rejects invalid category codes", () => {
    expect(normalizeCategory("../private")).toBeNull();
  });

  it("limits public search input length", () => {
    expect(normalizeSearch("x".repeat(150))).toHaveLength(100);
  });
});
