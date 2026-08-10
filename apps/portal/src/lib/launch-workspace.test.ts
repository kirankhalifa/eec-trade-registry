import { describe, expect, it } from "vitest";

import { parseLaunchWorkspace } from "./launch-workspace";

describe("parseLaunchWorkspace", () => {
  it("normalizes authoritative party names into select labels", () => {
    const result = parseLaunchWorkspace({
      applications: [],
      businesses: [],
      capabilities: {
        can_create_order: true,
        can_fulfill_asset: true,
        can_generate_documents: true,
        can_manage_finance: true,
        can_manage_pricing: true,
        can_review_applications: true,
      },
      consignment_agreements: [],
      direct_customers: [],
      document_sources: { fulfillments: [], licenses: [], orders: [], settlements: [] },
      items: [],
      jurisdictions: [],
      parties: [{ id: "00000000-0000-4000-8000-000000000001", name: "East Empire Company" }],
      price_schedules: [],
      price_targets: { dealer_types: [], jurisdictions: [], license_classes: [], parties: [] },
      settlement_candidates: [],
      settlements: [],
      unique_reservations: [],
    });

    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.parties).toEqual([
        { id: "00000000-0000-4000-8000-000000000001", label: "East Empire Company" },
      ]);
    }
  });
});
