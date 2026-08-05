import { z } from "zod";

const serviceEnvironmentSchema = z.object({
  NEXT_PUBLIC_SUPABASE_URL: z.string().url(),
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(40),
});

const googleEnvironmentSchema = z.object({
  GOOGLE_SERVICE_ACCOUNT_EMAIL: z.string().email(),
  GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY: z.string().min(100),
});

const discordDeliveryEnvironmentSchema = z.object({
  DISCORD_BOT_TOKEN: z.string().min(30),
});

const discordInteractionEnvironmentSchema = z.object({
  DISCORD_PUBLIC_KEY: z.string().regex(/^[a-fA-F0-9]{64}$/),
});

const discordRegistrationEnvironmentSchema = z.object({
  DISCORD_APPLICATION_ID: z.string().regex(/^\d{16,22}$/),
  DISCORD_BOT_TOKEN: z.string().min(30),
  DISCORD_GUILD_ID: z.string().regex(/^\d{16,22}$/).optional(),
});

export type IntegrationServiceEnvironment = z.infer<
  typeof serviceEnvironmentSchema
>;
export type GoogleServiceEnvironment = z.infer<
  typeof googleEnvironmentSchema
>;
export type DiscordDeliveryEnvironment = z.infer<
  typeof discordDeliveryEnvironmentSchema
>;

export function readIntegrationServiceEnvironment(
  environment: NodeJS.ProcessEnv = process.env,
): IntegrationServiceEnvironment {
  return serviceEnvironmentSchema.parse(environment);
}

export function readGoogleServiceEnvironment(
  environment: NodeJS.ProcessEnv = process.env,
): GoogleServiceEnvironment | null {
  const hasAnyGoogleValue = Boolean(
    environment.GOOGLE_SERVICE_ACCOUNT_EMAIL ||
      environment.GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY,
  );
  if (!hasAnyGoogleValue) return null;
  return googleEnvironmentSchema.parse(environment);
}

export function readDiscordDeliveryEnvironment(
  environment: NodeJS.ProcessEnv = process.env,
): DiscordDeliveryEnvironment | null {
  if (!environment.DISCORD_BOT_TOKEN) return null;
  return discordDeliveryEnvironmentSchema.parse(environment);
}

export function readDiscordPublicKey(
  environment: NodeJS.ProcessEnv = process.env,
): string | null {
  if (!environment.DISCORD_PUBLIC_KEY) return null;
  return discordInteractionEnvironmentSchema.parse(environment).DISCORD_PUBLIC_KEY;
}

export function readDiscordRegistrationEnvironment(
  environment: NodeJS.ProcessEnv = process.env,
) {
  return discordRegistrationEnvironmentSchema.parse(environment);
}

export function readCronSecret(
  environment: NodeJS.ProcessEnv = process.env,
): string | null {
  const secret = environment.CRON_SECRET?.trim();
  return secret && secret.length >= 16 ? secret : null;
}

export function getIntegrationWorkerId(
  environment: NodeJS.ProcessEnv = process.env,
): string {
  return environment.INTEGRATION_WORKER_ID?.trim() || "vercel-integrations";
}

export function getIntegrationRuntimeStatus(
  environment: NodeJS.ProcessEnv = process.env,
) {
  return {
    cron: Boolean(readCronSecret(environment)),
    discordDelivery: discordDeliveryEnvironmentSchema.safeParse(environment).success,
    discordInteractions: discordInteractionEnvironmentSchema.safeParse(environment).success,
    discordRegistration: discordRegistrationEnvironmentSchema.safeParse(environment).success,
    googleSheets: googleEnvironmentSchema.safeParse(environment).success,
    serviceRole: serviceEnvironmentSchema.safeParse(environment).success,
  };
}
