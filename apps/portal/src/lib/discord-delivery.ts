import type { DiscordDeliveryEnvironment } from "@/lib/integration-env";

export async function sendDiscordChannelMessage(input: {
  channelId: string;
  content: string;
  environment: DiscordDeliveryEnvironment;
}): Promise<string> {
  if (!/^\d{16,22}$/.test(input.channelId)) {
    throw new Error("discord_channel_invalid");
  }
  const response = await fetch(
    `https://discord.com/api/v10/channels/${input.channelId}/messages`,
    {
      method: "POST",
      headers: {
        authorization: `Bot ${input.environment.DISCORD_BOT_TOKEN}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        allowed_mentions: { parse: [] },
        content: input.content.slice(0, 1900),
      }),
      signal: AbortSignal.timeout(20_000),
    },
  );
  if (!response.ok) throw new Error(`discord_delivery_${response.status}`);
  const data = (await response.json()) as { id?: string };
  if (!data.id) throw new Error("discord_delivery_invalid_response");
  return data.id;
}
