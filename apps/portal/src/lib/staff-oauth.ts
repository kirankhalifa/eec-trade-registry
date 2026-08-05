import { getSiteOrigin } from "@/lib/env";

export function getStaffOAuthCallbackUrl(
  environment: NodeJS.ProcessEnv = process.env,
): string {
  return new URL("/auth/callback", getSiteOrigin(environment)).toString();
}

export function getStaffOAuthSuccessUrl(
  environment: NodeJS.ProcessEnv = process.env,
): URL {
  return new URL("/staff", getSiteOrigin(environment));
}

export function getStaffOAuthFailureUrl(
  reason: "cancelled" | "exchange_failed",
  environment: NodeJS.ProcessEnv = process.env,
): URL {
  const target = new URL("/staff/login", getSiteOrigin(environment));
  target.searchParams.set("error", reason);
  return target;
}
