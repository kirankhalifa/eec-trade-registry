import { describe, expect, it } from "vitest";

import {
  getIntegrationRuntimeStatus,
  readCronSecret,
  readGoogleServiceEnvironment,
} from "./integration-env";

function environment(values: Record<string, string> = {}): NodeJS.ProcessEnv {
  return { NODE_ENV: "test", ...values };
}

describe("integration environment", () => {
  it("reports readiness without returning secret material", () => {
    const status = getIntegrationRuntimeStatus(environment({
      CRON_SECRET: "a-secure-cron-secret",
      DISCORD_APPLICATION_ID: "123456789012345678",
      DISCORD_BOT_TOKEN: "x".repeat(40),
      DISCORD_PUBLIC_KEY: "a".repeat(64),
      GOOGLE_SERVICE_ACCOUNT_EMAIL: "worker@example.test",
      GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY: "x".repeat(120),
      NEXT_PUBLIC_SUPABASE_URL: "https://project.supabase.co",
      SUPABASE_SERVICE_ROLE_KEY: "x".repeat(40),
    }));
    expect(status).toEqual({
      cron: true,
      discordDelivery: true,
      discordInteractions: true,
      discordRegistration: true,
      googleSheets: true,
      serviceRole: true,
    });
    expect(Object.values(status).every((value) => typeof value === "boolean")).toBe(true);
  });

  it("fails closed on partial credential configuration", () => {
    expect(readGoogleServiceEnvironment(environment())).toBeNull();
    expect(() => readGoogleServiceEnvironment(environment({ GOOGLE_SERVICE_ACCOUNT_EMAIL: "worker@example.test" }))).toThrow();
  });

  it("requires a substantial cron secret", () => {
    expect(readCronSecret(environment({ CRON_SECRET: "short" }))).toBeNull();
  });
});
