import { generateKeyPairSync, sign as cryptoSign } from "node:crypto";
import { describe, expect, it } from "vitest";

import {
  handleDiscordInteraction,
  verifyDiscordInteractionSignature,
} from "./discord-interactions";

describe("Discord interactions", () => {
  it("verifies Ed25519 signatures over timestamp plus raw body", () => {
    const { privateKey, publicKey } = generateKeyPairSync("ed25519");
    const body = JSON.stringify({ type: 1 });
    const timestamp = "1785940800";
    const signature = cryptoSign(null, Buffer.from(`${timestamp}${body}`), privateKey);
    const publicDer = publicKey.export({ format: "der", type: "spki" });
    const publicKeyHex = publicDer.subarray(publicDer.length - 32).toString("hex");
    expect(
      verifyDiscordInteractionSignature({
        body,
        nowSeconds: Number(timestamp),
        publicKeyHex,
        signatureHex: signature.toString("hex"),
        timestamp,
      }),
    ).toBe(true);
    expect(
      verifyDiscordInteractionSignature({
        body: `${body} `,
        nowSeconds: Number(timestamp),
        publicKeyHex,
        signatureHex: signature.toString("hex"),
        timestamp,
      }),
    ).toBe(false);
  });

  it("rejects otherwise valid replayed requests outside the freshness window", () => {
    const { privateKey, publicKey } = generateKeyPairSync("ed25519");
    const body = JSON.stringify({ type: 1 });
    const timestamp = "1785940800";
    const signature = cryptoSign(null, Buffer.from(`${timestamp}${body}`), privateKey);
    const publicDer = publicKey.export({ format: "der", type: "spki" });
    expect(
      verifyDiscordInteractionSignature({
        body,
        nowSeconds: Number(timestamp) + 301,
        publicKeyHex: publicDer.subarray(publicDer.length - 32).toString("hex"),
        signatureHex: signature.toString("hex"),
        timestamp,
      }),
    ).toBe(false);
  });

  it("handles Discord endpoint verification without querying business data", async () => {
    await expect(handleDiscordInteraction({ type: 1 })).resolves.toEqual({
      body: { type: 1 },
      status: 200,
    });
    await expect(handleDiscordInteraction({ type: "wrong" })).resolves.toEqual({
      body: { code: "invalid_interaction" },
      status: 400,
    });
  });
});
