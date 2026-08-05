import { describe, expect, it } from "vitest";

import {
  readConfigureDestinationForm,
  readReplayDeliveryForm,
  readSetDefinitionStatusForm,
} from "./staff-integration-form";

const destinationId = "10000000-0000-0000-0000-000000000001";

describe("staff integration forms", () => {
  it("requires a destination reference when activating", () => {
    const form = new FormData();
    form.set("destination_id", destinationId);
    form.set("expected_version", "1");
    form.set("active", "on");
    form.set("reason", "Enable the approved public projection.");
    expect(readConfigureDestinationForm(form).success).toBe(false);
    form.set("external_reference", "spreadsheet-id");
    expect(readConfigureDestinationForm(form).success).toBe(true);
  });

  it("allows a destination to be safely deactivated", () => {
    const form = new FormData();
    form.set("destination_id", destinationId);
    form.set("expected_version", "2");
    form.set("reason", "Pause publication during maintenance.");
    const parsed = readConfigureDestinationForm(form);
    expect(parsed.success).toBe(true);
    if (parsed.success) expect(parsed.data.active).toBe(false);
  });

  it("requires optimistic versions and audit reasons", () => {
    const form = new FormData();
    form.set("definition_id", destinationId);
    form.set("expected_version", "0");
    form.set("reason", "");
    expect(readSetDefinitionStatusForm(form).success).toBe(false);

    const replay = new FormData();
    replay.set("delivery_id", destinationId);
    expect(readReplayDeliveryForm(replay).success).toBe(false);
  });
});
