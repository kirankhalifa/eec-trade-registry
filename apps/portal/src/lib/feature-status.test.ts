import { existsSync } from "node:fs";
import path from "node:path";

import { describe, expect, it } from "vitest";

import { FEATURES } from "./feature-status";

describe("feature status manifest", () => {
  it("does not expose an application route for a gated feature", () => {
    for (const feature of Object.values(FEATURES)) {
      if (feature.status !== "gated" || !feature.route) continue;
      const routePath = path.join(process.cwd(), "src", "app", ...feature.route.split("/").filter(Boolean));
      expect(existsSync(routePath), `${feature.label} is gated but has a route`).toBe(false);
    }
  });

  it("gives every live feature a route", () => {
    for (const feature of Object.values(FEATURES)) {
      if (feature.status === "live") expect(feature.route, feature.label).toBeTruthy();
    }
  });
});
