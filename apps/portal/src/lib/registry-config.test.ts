import { describe, expect, it } from "vitest";

import {
  isConfiguredOrderChannel,
  REGISTRY_CONFIG,
} from "@/lib/registry-config";

describe("registry deployment decisions", () => {
  it("keeps fixed launch decisions out of routine forms", () => {
    expect(REGISTRY_CONFIG.currency).toEqual({ code: "SEP", label: "Septims" });
    expect(REGISTRY_CONFIG.jurisdiction.mode).toBe("fixed");
    expect(REGISTRY_CONFIG.warehouse.mode).toBe("single");
    expect(REGISTRY_CONFIG.pricing.exposeTiePriority).toBe(false);
  });

  it("admits only the two launch ordering channels", () => {
    expect(isConfiguredOrderChannel("business")).toBe(true);
    expect(isConfiguredOrderChannel("direct")).toBe(true);
    expect(isConfiguredOrderChannel("dealer_portal")).toBe(false);
  });
});
