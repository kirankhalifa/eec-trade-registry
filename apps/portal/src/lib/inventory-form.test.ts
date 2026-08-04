import { describe, expect, it } from "vitest";

import {
  readCreateReservationForm,
  readExtendReservationForm,
  readInventoryReceiptForm,
  readReservationMutationForm,
  readReverseInventoryForm,
} from "./inventory-form";

const ids = {
  account: "10000000-0000-0000-0000-000000000001",
  item: "20000000-0000-0000-0000-000000000001",
  line: "30000000-0000-0000-0000-000000000001",
  location: "40000000-0000-0000-0000-000000000001",
  reservation: "50000000-0000-0000-0000-000000000001",
  transaction: "60000000-0000-0000-0000-000000000001",
};

describe("inventory form parsing", () => {
  it("parses a positive receipt with provenance", () => {
    const form = new FormData();
    form.set("stock_location_id", ids.location);
    form.set("item_id", ids.item);
    form.set("quantity", "12.5");
    form.set("source_reference", "MANIFEST-42");
    form.set("reason", "Receive inspected stock.");
    const parsed = readInventoryReceiptForm(form);
    expect(parsed.success).toBe(true);
    if (parsed.success) expect(parsed.data.quantity).toBe(12.5);
  });

  it("rejects zero inventory and reservation quantities", () => {
    const receipt = new FormData();
    receipt.set("stock_location_id", ids.location);
    receipt.set("item_id", ids.item);
    receipt.set("quantity", "0");
    receipt.set("source_reference", "MANIFEST-42");
    receipt.set("reason", "Receive stock.");
    expect(readInventoryReceiptForm(receipt).success).toBe(false);

    const reservation = new FormData();
    reservation.set("inventory_account_id", ids.account);
    reservation.set("order_line_id", ids.line);
    reservation.set("quantity", "0");
    reservation.set("reason", "Reserve stock.");
    expect(readCreateReservationForm(reservation).success).toBe(false);
  });

  it("normalizes an extension instant", () => {
    const form = new FormData();
    form.set("reservation_id", ids.reservation);
    form.set("expected_version", "2");
    form.set("expires_at", "2026-08-08T10:30");
    form.set("reason", "Authorized collection extension.");
    const parsed = readExtendReservationForm(form);
    expect(parsed.success).toBe(true);
    if (parsed.success) expect(parsed.data.expiresAt).toContain("2026-08-08T");
  });

  it("requires optimistic versions and reasons for release", () => {
    const form = new FormData();
    form.set("reservation_id", ids.reservation);
    form.set("expected_version", "0");
    form.set("reason", "");
    expect(readReservationMutationForm(form).success).toBe(false);
  });

  it("parses a linked reversal request", () => {
    const form = new FormData();
    form.set("inventory_transaction_id", ids.transaction);
    form.set("reason", "Correct the documented receipt error.");
    expect(readReverseInventoryForm(form).success).toBe(true);
  });
});
