import { discordCommands } from "@/lib/discord-commands";
import type { readDiscordRegistrationEnvironment } from "@/lib/integration-env";

type RegistrationEnvironment = ReturnType<typeof readDiscordRegistrationEnvironment>;

export async function registerDiscordCommands(
  environment: RegistrationEnvironment,
): Promise<{ commandCount: number; scope: "global" | "guild" }> {
  const scope = environment.DISCORD_GUILD_ID ? "guild" : "global";
  const path = environment.DISCORD_GUILD_ID
    ? `/applications/${environment.DISCORD_APPLICATION_ID}/guilds/${environment.DISCORD_GUILD_ID}/commands`
    : `/applications/${environment.DISCORD_APPLICATION_ID}/commands`;
  const response = await fetch(`https://discord.com/api/v10${path}`, {
    method: "PUT",
    headers: {
      authorization: `Bot ${environment.DISCORD_BOT_TOKEN}`,
      "content-type": "application/json",
    },
    body: JSON.stringify(discordCommands),
    signal: AbortSignal.timeout(20_000),
  });
  if (!response.ok) throw new Error(`discord_registration_${response.status}`);
  const registered = (await response.json()) as unknown;
  if (!Array.isArray(registered)) throw new Error("discord_registration_invalid_response");
  return { commandCount: registered.length, scope };
}
