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
