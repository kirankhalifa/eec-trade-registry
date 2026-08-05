import {
  handleDiscordInteraction,
  verifyDiscordInteractionSignature,
} from "@/lib/discord-interactions";
import { readDiscordPublicKey } from "@/lib/integration-env";

export async function POST(request: Request) {
  const publicKey = readDiscordPublicKey();
  if (!publicKey) {
    return Response.json({ code: "discord_not_configured" }, { status: 503 });
  }
  const body = await request.text();
  if (body.length > 64_000) {
    return Response.json({ code: "request_too_large" }, { status: 413 });
  }
  const valid = verifyDiscordInteractionSignature({
    body,
    publicKeyHex: publicKey,
    signatureHex: request.headers.get("x-signature-ed25519"),
    timestamp: request.headers.get("x-signature-timestamp"),
  });
  if (!valid) return Response.json({ code: "invalid_signature" }, { status: 401 });
  let payload: unknown;
  try {
    payload = JSON.parse(body);
  } catch {
    return Response.json({ code: "invalid_json" }, { status: 400 });
  }
  const response = await handleDiscordInteraction(payload);
  return Response.json(response.body, { status: response.status });
}
