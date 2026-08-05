import { registerDiscordCommands } from "@/lib/discord-registration";
import { hasValidBearerSecret } from "@/lib/integration-auth";
import {
  readCronSecret,
  readDiscordRegistrationEnvironment,
} from "@/lib/integration-env";

export async function POST(request: Request) {
  const secret = readCronSecret();
  if (!secret) return Response.json({ code: "admin_api_not_configured" }, { status: 503 });
  if (!hasValidBearerSecret(request.headers.get("authorization"), secret)) {
    return Response.json({ code: "unauthorized" }, { status: 401 });
  }
  try {
    const result = await registerDiscordCommands(readDiscordRegistrationEnvironment());
    return Response.json({ ok: true, ...result });
  } catch (error) {
    const code =
      error instanceof Error && /^[a-z0-9_]{3,100}$/.test(error.message)
        ? error.message
        : "discord_registration_failed";
    return Response.json({ code }, { status: 502 });
  }
}
