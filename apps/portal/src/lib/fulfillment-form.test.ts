import { describe, expect, it } from "vitest";

import {
  readFulfillReservationForm,
  readReverseFulfillmentForm,
} from "./fulfillment-form";

const ids = {
  fulfillment: "10000000-0000-0000-0000-000000000001",
  reservation: "20000000-0000-0000-0000-000000000001",
};

describe("fulfillment form parsing", () => {
  it("parses reservation completion with an optimistic version", () => {
    const form = new FormData();
    form.set("reservation_id", ids.reservation);
    form.set("expected_version", "3");
    form.set("reason", "Release the inspected goods for collection.");
    const parsed = readFulfillReservationForm(form);
    expect(parsed.success).toBe(true);
    if (parsed.success) expect(parsed.data.expectedVersion).toBe(3);
  });

  it("rejects a missing completion reason", () => {
    const form = new FormData();
    form.set("reservation_id", ids.reservation);
    form.set("expected_version", "1");
    form.set("reason", "");
    expect(readFulfillReservationForm(form).success).toBe(false);
  });

  it("parses a controlled fulfillment reversal", () => {
    const form = new FormData();
    form.set("fulfillment_id", ids.fulfillment);
    form.set("expected_version", "1");
    form.set("reason", "Correct the recorded handoff and restore stock.");
    expect(readReverseFulfillmentForm(form).success).toBe(true);
  });
});
