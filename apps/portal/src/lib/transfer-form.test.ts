import { describe, expect, it } from "vitest";

import { readCreateTransferForm, readTransferCommandForm } from "./transfer-form";

const firstId = "10000000-0000-4000-8000-000000000001";
const secondId = "10000000-0000-4000-8000-000000000002";

describe("transfer forms", () => {
  it("parses a valid transfer request", () => {
    const form = new FormData();
    form.set("source_inventory_account_id", firstId);
    form.set("destination_inventory_account_id", secondId);
    form.set("quantity", "4.5");
    form.set("reason", "Regional replenishment");
    const result = readCreateTransferForm(form);
    expect(result.success).toBe(true);
    if (result.success) expect(result.data.quantity).toBe(4.5);
  });

  it("rejects a request whose source and destination are identical", () => {
    const form = new FormData();
    form.set("source_inventory_account_id", firstId);
    form.set("destination_inventory_account_id", firstId);
    form.set("quantity", "1");
    form.set("reason", "Invalid route");
    expect(readCreateTransferForm(form).success).toBe(false);
  });

  it("requires a positive optimistic version and audit reason", () => {
    const form = new FormData();
    form.set("stock_transfer_id", firstId);
    form.set("expected_version", "0");
    form.set("reason", "");
    expect(readTransferCommandForm(form).success).toBe(false);
  });
});
