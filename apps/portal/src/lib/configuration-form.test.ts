import { describe, expect, it } from "vitest";

import {
  readConfigurationReferenceForm,
  readPublicTermsForm,
  readQuickItemForm,
  readQuickReceiptForm,
} from "@/lib/configuration-form";

const ids = {
  item: "10000000-0000-4000-8000-000000000001",
  location: "10000000-0000-4000-8000-000000000002",
  schedule: "10000000-0000-4000-8000-000000000003",
};

describe("rapid configuration forms", () => {
  it("parses a minimal quick item and preserves omitted policy values as null", () => {
    const form = new FormData();
    form.set("display_name", "Iron fittings");
    form.set("category_code", "smithed-goods");
    form.set("unit_code", "each");
    form.set("supply_mode", "warehouse_stocked");
    form.set("control_profile_code", "ordinary");
    form.set("availability_profile_code", "available");
    form.set("publish", "on");
    const parsed = readQuickItemForm(form);
    expect(parsed.success).toBe(true);
    if (parsed.success) {
      expect(parsed.data.itemCode).toBe("");
      expect(parsed.data.openingQuantity).toBeNull();
      expect(parsed.data.priceAmountMinor).toBeNull();
      expect(parsed.data.publish).toBe(true);
      expect(parsed.data.targetLevel).toBeNull();
    }
  });

  it("rejects generic opening stock for a player-sourced reserve", () => {
    const form = new FormData();
    form.set("display_name", "Silver ore");
    form.set("category_code", "raw-materials");
    form.set("unit_code", "material-unit");
    form.set("supply_mode", "player_sourced_reserve");
    form.set("control_profile_code", "ordinary-economic");
    form.set("availability_profile_code", "reserve-dependent");
    form.set("opening_stock_location_id", ids.location);
    form.set("opening_quantity", "25");
    expect(readQuickItemForm(form).success).toBe(false);
  });

  it("parses the three-field quick receipt", () => {
    const form = new FormData();
    form.set("item_code", "ITM-1001");
    form.set("quantity", "40");
    form.set("stock_location_id", ids.location);
    const parsed = readQuickReceiptForm(form);
    expect(parsed.success).toBe(true);
    if (parsed.success) expect(parsed.data.sourceReference).toBe("");
  });

  it("parses a new configurable license class", () => {
    const form = new FormData();
    form.set("kind", "license_class");
    form.set("code", "special-trade");
    form.set("display_name", "Special trade");
    form.set("public_display_name", "Special trade");
    const parsed = readConfigurationReferenceForm(form);
    expect(parsed.success).toBe(true);
    if (parsed.success) expect(parsed.data.quantityScale).toBe(0);
  });

  it("requires an explicit amount when replacing a price", () => {
    const form = new FormData();
    form.set("item_id", ids.item);
    form.set("publish", "on");
    form.set("public_name", "Iron fittings");
    form.set("public_description", "Fittings for routine construction.");
    form.set("control_profile_code", "ordinary");
    form.set("availability_profile_code", "available");
    form.set("requirement_summary", "Available through current trade terms.");
    form.set("order_increment", "1");
    form.set("price_action", "set");
    form.set("price_schedule_id", ids.schedule);
    expect(readPublicTermsForm(form).success).toBe(false);
  });
});
