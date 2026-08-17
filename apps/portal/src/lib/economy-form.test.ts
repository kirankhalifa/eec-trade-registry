import { describe, expect, it } from "vitest";

import {
  readDeliveryForm, readOfferForm, readSettlementForm, readSupplierForm, readSupplyPolicyForm,
} from "@/lib/economy-form";

const id = (suffix: number) => `10000000-0000-4000-8000-${String(suffix).padStart(12, "0")}`;
function form(entries: Record<string, string>) {
  const value = new FormData();
  Object.entries(entries).forEach(([key, entry]) => value.set(key, entry));
  return value;
}

describe("economy forms", () => {
  it("parses nullable reserve thresholds without inventing zeroes", () => {
    const result = readSupplyPolicyForm(form({
      admin_receipt_allowed: "", business_bulk_review_threshold: "100",
      critical_level: "", direct_individual_allowed: "on", direct_weekly_limit: "5",
      expected_version: "2", item_id: id(1), minimum_level: "20",
      player_sourced_only: "on", procurement_enabled: "on", reason: "Approved reserve corridor",
      supply_mode: "player_sourced_reserve", surplus_level: "100", target_level: "60",
    }));
    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.criticalLevel).toBeNull();
      expect(result.data.playerSourcedOnly).toBe(true);
      expect(result.data.businessBulkReviewThreshold).toBe(100);
    }
  });

  it("rejects a supplier without an audit reason", () => {
    expect(readSupplierForm(form({
      display_name: "Mine Foreman", jurisdiction_id: id(2), legal_name: "Aurelia",
      notes: "", party_type_code: "individual", reason: "",
    })).success).toBe(false);
  });

  it("uses the supplier name as the display name in quick intake", () => {
    const result = readSupplierForm(form({
      display_name: "", jurisdiction_id: id(2), legal_name: "Ragnar the Miner",
      notes: "", party_type_code: "individual", reason: "Registered at receiving",
    }));
    expect(result.success).toBe(true);
    if (result.success) expect(result.data.displayName).toBe("Ragnar the Miner");
  });

  it("parses an effective-dated purchase offer", () => {
    const result = readOfferForm(form({
      amount_minor: "25", currency_id: id(3), effective_from: "2026-08-10T12:00",
      effective_until: "", item_id: id(4), minimum_quantity: "10", notes: "Floor rate",
      reason: "Economic policy approval", staff_review_quantity: "250",
    }));
    expect(result.success).toBe(true);
    if (result.success) expect(result.data.effectiveUntil).toBeNull();
  });

  it("requires positive delivery quantity", () => {
    expect(readDeliveryForm(form({
      offer_id: id(5), quantity: "0", reason: "Accepted at warehouse",
      stock_location_id: id(6), supplier_id: id(7),
    })).success).toBe(false);
  });

  it("requires external payment evidence to settle", () => {
    expect(readSettlementForm(form({
      delivery_id: id(8), expected_version: "1", reason: "Paid at counter",
      settlement_reference: "",
    })).success).toBe(false);
  });
});
