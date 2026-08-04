import { describe, expect, it } from "vitest";

import {
  createCatalogueItemSchema,
  setCatalogueStatusSchema,
  updateCatalogueItemSchema,
} from "@/lib/staff-catalogue-form";

const validMutableFields = {
  displayName: "Harbor crate",
  description: "A sturdy shipping crate.",
  categoryCode: "equipment",
  unitCode: "each",
  inventoryMode: "fungible" as const,
  internalNotes: "Internal handling note.",
  reason: "Create an initial draft.",
};

describe("staff catalogue form schemas", () => {
  it("accepts a valid canonical item draft", () => {
    expect(
      createCatalogueItemSchema.safeParse({
        ...validMutableFields,
        itemCode: "EQ-CRATE-001",
        slug: "harbor-crate",
      }).success,
    ).toBe(true);
  });

  it("rejects unstable item codes and slugs", () => {
    expect(
      createCatalogueItemSchema.safeParse({
        ...validMutableFields,
        itemCode: "contains spaces",
        slug: "Contains Capitals",
      }).success,
    ).toBe(false);
  });

  it("requires an explicit audit reason", () => {
    expect(
      createCatalogueItemSchema.safeParse({
        ...validMutableFields,
        itemCode: "EQ-CRATE-001",
        slug: "harbor-crate",
        reason: "",
      }).success,
    ).toBe(false);
  });

  it("requires a positive concurrency version for updates", () => {
    expect(
      updateCatalogueItemSchema.safeParse({
        ...validMutableFields,
        itemId: "10000000-0000-0000-0000-000000000001",
        expectedVersion: 0,
      }).success,
    ).toBe(false);
  });

  it("allows only active and archived status transitions", () => {
    expect(
      setCatalogueStatusSchema.safeParse({
        itemId: "10000000-0000-0000-0000-000000000001",
        expectedVersion: 2,
        status: "deleted",
        reason: "Remove the item.",
      }).success,
    ).toBe(false);
  });
});
