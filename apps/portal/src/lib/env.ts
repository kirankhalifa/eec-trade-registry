import { z } from "zod";

const publicSupabaseEnvironmentSchema = z.object({
  NEXT_PUBLIC_SUPABASE_URL: z.string().url(),
  NEXT_PUBLIC_SUPABASE_ANON_KEY: z.string().min(20),
});

export type PublicSupabaseEnvironment = z.infer<
  typeof publicSupabaseEnvironmentSchema
>;

export function readPublicSupabaseEnvironment(
  environment: NodeJS.ProcessEnv = process.env,
): PublicSupabaseEnvironment | null {
  const result = publicSupabaseEnvironmentSchema.safeParse(environment);
  return result.success ? result.data : null;
}

export function getSiteOrigin(
  environment: NodeJS.ProcessEnv = process.env,
): string {
  const configured = environment.NEXT_PUBLIC_SITE_URL?.trim();
  if (!configured) {
    if (environment.NODE_ENV === "production") {
      throw new Error("NEXT_PUBLIC_SITE_URL is required in production.");
    }
    return "http://127.0.0.1:3000";
  }

  const url = new URL(configured);
  if (
    url.username ||
    url.password ||
    url.search ||
    url.hash ||
    (url.pathname !== "/" && url.pathname !== "")
  ) {
    throw new Error("NEXT_PUBLIC_SITE_URL must contain only an origin.");
  }
  if (environment.NODE_ENV === "production" && url.protocol !== "https:") {
    throw new Error("NEXT_PUBLIC_SITE_URL must use HTTPS in production.");
  }

  return url.origin;
}

export function getInstitutionName(
  environment: NodeJS.ProcessEnv = process.env,
): string {
  return environment.NEXT_PUBLIC_INSTITUTION_NAME?.trim() || "East Empire Company";
}

export function getDefaultLocale(
  environment: NodeJS.ProcessEnv = process.env,
): string {
  return environment.NEXT_PUBLIC_DEFAULT_LOCALE?.trim() || "en-US";
}
