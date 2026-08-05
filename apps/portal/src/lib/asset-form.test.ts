import { describe, expect, it } from "vitest";

import {
  readAssetLifecycleForm,
  readInspectAssetForm,
  readRegisterAssetForm,
  readTransferAssetForm,
} from "./asset-form";

const assetId = "10000000-0000-4000-8000-000000000001";
const locationId = "10000000-0000-4000-8000-000000000002";

describe("asset forms", () => {
  it("parses serialized registration", () => {
    const form = new FormData();
    form.set("item_id", assetId); form.set("stock_location_id", locationId);
    form.set("serial_marking", "SER-1"); form.set("condition_code", "good");
    form.set("provenance_summary", "Recorded source"); form.set("reason", "Initial registration");
    expect(readRegisterAssetForm(form).success).toBe(true);
  });
  it("requires a typed custody destination", () => {
    const form = new FormData();
    form.set("asset_id", assetId); form.set("expected_version", "2");
    form.set("destination", locationId); form.set("condition_code", "fair"); form.set("reason", "Move");
    expect(readTransferAssetForm(form).success).toBe(false);
    form.set("destination", `location:${locationId}:${assetId}`);
    expect(readTransferAssetForm(form).success).toBe(true);
  });
  it("accepts an optional inspection due date", () => {
    const form = new FormData();
    form.set("asset_id", assetId); form.set("expected_version", "2");
    form.set("condition_code", "fair"); form.set("observation", "Serviceable");
    form.set("next_due_date", "2027-01-15"); form.set("reason", "Inspection");
    expect(readInspectAssetForm(form).success).toBe(true);
  });
  it("rejects invented lifecycle states", () => {
    const form = new FormData();
    form.set("asset_id", assetId); form.set("expected_version", "2");
    form.set("status", "deleted"); form.set("reason", "Invalid");
    expect(readAssetLifecycleForm(form).success).toBe(false);
  });
});
