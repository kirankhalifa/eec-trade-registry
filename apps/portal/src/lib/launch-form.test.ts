import { describe, expect, it } from "vitest";
import { readAssistedOrderForm } from "@/lib/launch-form";

describe("launch command forms", () => {
  it("accepts a fast direct-individual order with one authoritative line", () => {
    const form = new FormData();
    form.set("channel", "direct_individual"); form.set("business_key", ""); form.set("direct_customer_id", "");
    form.set("new_customer_name", "Aurelion Earandil"); form.set("contact_label", "aurelion");
    form.set("jurisdiction_id", "90000000-0000-0000-0000-000000000001"); form.set("fulfillment_mode", "collection");
    form.set("notes", "Personal request"); form.set("reason", "Entered during counter service.");
    form.set("item_id_1", "80000000-0000-0000-0000-000000000001"); form.set("quantity_1", "1");
    const result = readAssistedOrderForm(form);
    expect(result.success).toBe(true);
    if (result.success) expect(result.data.lines).toEqual([{ item_id: "80000000-0000-0000-0000-000000000001", quantity: 1 }]);
  });

  it("rejects an order with no line", () => {
    const form = new FormData(); form.set("channel", "direct_individual"); form.set("reason", "Missing goods.");
    expect(readAssistedOrderForm(form).success).toBe(false);
  });
});
