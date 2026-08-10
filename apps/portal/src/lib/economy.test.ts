import type { SupabaseClient } from "@supabase/supabase-js";
import { describe, expect, it } from "vitest";

import { getStaffEconomyWorkspace } from "@/lib/economy";

describe("economy workspace", () => {
  it("preserves unset policy numbers as null instead of coercing them to zero", async () => {
    const data = {
      currencies: [], deliveries: [], generated_at: "2026-08-10T00:00:00Z",
      jurisdictions: [], offers: [], party_types: [], suppliers: [], warehouses: [],
      positions: [{
        admin_receipt_allowed: false, available: "0.000", backordered: "0.000",
        business_bulk_review_threshold: null, committed_7d_minor: 0, critical_level: null,
        direct_individual_allowed: false, direct_weekly_limit: null, item_code: "RM-IRON-ORE",
        item_id: "ce000000-0000-0000-0000-000000000001", item_name: "Iron Ore",
        minimum_level: null, on_hand: "0.000", paid_7d_minor: 0, player_sourced_only: true,
        policy_version: 1, procured_7d: "0.000", procurement_enabled: true,
        reserve_state: "unconfigured", reserved: "0.000", supply_mode: "player_sourced_reserve",
        surplus_level: null, target_level: null, unit_code: "material-unit",
      }],
    };
    const client = { rpc: async () => ({ data, error: null }) } as unknown as SupabaseClient;
    const result = await getStaffEconomyWorkspace(client);
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.data.positions[0]?.target_level).toBeNull();
      expect(result.data.positions[0]?.direct_weekly_limit).toBeNull();
    }
  });
});
