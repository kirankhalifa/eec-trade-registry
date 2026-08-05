import { describe, expect, it } from "vitest";

import { getSiteOrigin } from "@/lib/env";
import {
  getStaffOAuthCallbackUrl,
  getStaffOAuthFailureUrl,
  getStaffOAuthSuccessUrl,
} from "@/lib/staff-oauth";

describe("staff OAuth destinations", () => {
  const productionEnvironment = {
    NODE_ENV: "production",
    NEXT_PUBLIC_SITE_URL: "https://registry.example.test",
  } as NodeJS.ProcessEnv;

  it("uses the configured production origin for fixed staff routes", () => {
    expect(getStaffOAuthCallbackUrl(productionEnvironment)).toBe(
      "https://registry.example.test/auth/callback",
    );
    expect(getStaffOAuthSuccessUrl(productionEnvironment).toString()).toBe(
      "https://registry.example.test/staff",
    );
    expect(
      getStaffOAuthFailureUrl(
        "exchange_failed",
        productionEnvironment,
      ).toString(),
    ).toBe(
      "https://registry.example.test/staff/login?error=exchange_failed",
    );
  });

  it("does not accept paths or query strings in the trusted site origin", () => {
    expect(() =>
      getSiteOrigin({
        NODE_ENV: "production",
        NEXT_PUBLIC_SITE_URL: "https://registry.example.test/not-an-origin",
      } as NodeJS.ProcessEnv),
    ).toThrow("must contain only an origin");
  });

  it("requires HTTPS and an explicit origin in production", () => {
    expect(() =>
      getSiteOrigin({
        NODE_ENV: "production",
        NEXT_PUBLIC_SITE_URL: "http://registry.example.test",
      } as NodeJS.ProcessEnv),
    ).toThrow("must use HTTPS");
    expect(() =>
      getSiteOrigin({ NODE_ENV: "production" } as NodeJS.ProcessEnv),
    ).toThrow("required in production");
  });

  it("uses the local portal origin outside production", () => {
    expect(getSiteOrigin({ NODE_ENV: "test" } as NodeJS.ProcessEnv)).toBe(
      "http://127.0.0.1:3000",
    );
  });
});
