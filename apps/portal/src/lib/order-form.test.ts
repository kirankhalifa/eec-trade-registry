import { describe, expect, it } from "vitest";

import {
  readCancelOrderForm,
  readPriceOrderLineForm,
  readReviewOrderLineForm,
  readSubmitOrderForm,
} from "./order-form";

const partyId = "11111111-1111-4111-8111-111111111111";
const dealerId = "22222222-2222-4222-8222-222222222222";
const orderId = "33333333-3333-4333-8333-333333333333";
const lineId = "44444444-4444-4444-8444-444444444444";
const itemOne = "55555555-5555-4555-8555-555555555555";
const itemTwo = "66666666-6666-4666-8666-666666666666";

describe("order form parsing", () => {
  it("parses a multi-line order without a license or configured price", () => {
    const form = new FormData();
    form.set("ordering_party_id", partyId);
    form.set("dealer_authorization_id", dealerId);
    form.set("license_id", "");
    form.set("fulfillment_mode", "collection");
    form.append("item_ids", itemOne);
    form.append("quantities", "3");
    form.append("item_ids", itemTwo);
    form.append("quantities", "1.5");
    form.set("dealer_notes", "Stock may arrive later.");
    form.set("reason", "Submit a wholesale requisition for staff review.");

    const result = readSubmitOrderForm(form);

    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.licenseId).toBeNull();
      expect(result.data.lines).toHaveLength(2);
      expect(result.data.lines[1]?.quantity).toBe(1.5);
    }
  });

  it("rejects duplicate order items", () => {
    const form = new FormData();
    form.set("ordering_party_id", partyId);
    form.set("dealer_authorization_id", dealerId);
    form.set("fulfillment_mode", "delivery");
    form.append("item_ids", itemOne);
    form.append("quantities", "1");
    form.append("item_ids", itemOne);
    form.append("quantities", "2");
    form.set("reason", "Duplicate line test.");

    expect(readSubmitOrderForm(form).success).toBe(false);
  });

  it("parses awaiting-stock review with blank price", () => {
    const form = new FormData();
    form.set("order_id", orderId);
    form.set("order_line_id", lineId);
    form.set("expected_order_version", "2");
    form.set("decision", "awaiting_stock");
    form.set("approved_quantity", "4");
    form.set("unit_price_minor", "");
    form.set("reason", "Approve commercially while awaiting warehouse stock.");

    const result = readReviewOrderLineForm(form);

    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.unitPriceMinor).toBeNull();
      expect(result.data.approvedQuantity).toBe(4);
    }
  });

  it("parses clearing a price and cancelling an order", () => {
    const price = new FormData();
    price.set("order_id", orderId);
    price.set("order_line_id", lineId);
    price.set("expected_order_version", "3");
    price.set("unit_price_minor", "");
    price.set("reason", "Return the line to pending pricing.");

    const cancel = new FormData();
    cancel.set("order_id", orderId);
    cancel.set("expected_version", "4");
    cancel.set("reason", "Cancel before fulfillment.");

    expect(readPriceOrderLineForm(price).success).toBe(true);
    expect(readCancelOrderForm(cancel).success).toBe(true);
  });
});
