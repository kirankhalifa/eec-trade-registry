import { createPublicKey, verify } from "node:crypto";
import { z } from "zod";

import { getPublicCatalogue } from "@/lib/catalogue";
import { getDefaultLocale, getSiteOrigin } from "@/lib/env";
import { formatMinorAmount } from "@/lib/format";
import { verifyPublicDealer, verifyPublicLicense } from "@/lib/verification";

const interactionSchema = z.object({
  data: z
    .object({
      name: z.string(),
      options: z
        .array(
          z.object({
            name: z.string(),
            value: z.union([z.string(), z.number(), z.boolean()]),
          }),
        )
        .optional(),
    })
    .optional(),
  type: z.number().int(),
});

type Interaction = z.infer<typeof interactionSchema>;

export function verifyDiscordInteractionSignature(input: {
  body: string;
  nowSeconds?: number;
  publicKeyHex: string;
  signatureHex: string | null;
  timestamp: string | null;
}): boolean {
  if (
    !input.signatureHex ||
    !/^[a-fA-F0-9]{128}$/.test(input.signatureHex) ||
    !input.timestamp ||
    !/^\d{10,11}$/.test(input.timestamp) ||
    !/^[a-fA-F0-9]{64}$/.test(input.publicKeyHex)
  ) {
    return false;
  }
  try {
    const requestSeconds = Number(input.timestamp);
    const nowSeconds = input.nowSeconds ?? Math.floor(Date.now() / 1_000);
    if (!Number.isSafeInteger(requestSeconds) || Math.abs(nowSeconds - requestSeconds) > 300) {
      return false;
    }
    const spkiPrefix = Buffer.from("302a300506032b6570032100", "hex");
    const key = createPublicKey({
      format: "der",
      key: Buffer.concat([spkiPrefix, Buffer.from(input.publicKeyHex, "hex")]),
      type: "spki",
    });
    return verify(
      null,
      Buffer.from(`${input.timestamp}${input.body}`, "utf8"),
      key,
      Buffer.from(input.signatureHex, "hex"),
    );
  } catch {
    return false;
  }
}

function option(interaction: Interaction, name: string): string | null {
  const value = interaction.data?.options?.find((entry) => entry.name === name)?.value;
  return typeof value === "string" ? value.trim() : null;
}

function message(content: string) {
  return {
    data: { allowed_mentions: { parse: [] }, content: content.slice(0, 1900) },
    type: 4,
  };
}

function unavailable() {
  return message("The authoritative registry is temporarily unavailable. No fallback data was used.");
}

async function catalogueResponse(interaction: Interaction) {
  const query = option(interaction, "query");
  if (!query) return message("Provide an item name or code to search the public catalogue.");
  const result = await getPublicCatalogue({ category: null, search: query });
  if (!result.ok) return unavailable();
  if (result.data.length === 0) return message("No published catalogue entry matched that search.");
  const locale = getDefaultLocale();
  const origin = getSiteOrigin();
  const lines = result.data.slice(0, 5).map((item) => {
    const price = formatMinorAmount(
      item.price_amount_minor,
      item.currency_symbol,
      item.currency_symbol_position,
      item.minor_unit_scale,
      locale,
    );
    return `**${item.display_name}** (${item.item_code}) — ${price ?? "price by request"}; ${item.availability_label}. ${origin}/catalogue/${item.slug}`;
  });
  return message(lines.join("\n"));
}

async function dealerResponse(interaction: Interaction) {
  const reference = option(interaction, "reference");
  if (!reference) return message("Provide an exact public dealer reference.");
  const result = await verifyPublicDealer(reference);
  if (!result.ok) return unavailable();
  if (result.data.result_code === "not_verifiable") {
    return message("That reference is not verifiable in the public registry.");
  }
  const data = result.data;
  return message(
    `**${data.public_name}** — ${data.status_label}. Reference: ${data.public_reference}. Type: ${data.dealer_type_label}. Jurisdiction: ${data.jurisdiction_label}. Currently authorized: ${data.is_currently_authorized ? "yes" : "no"}.`,
  );
}

async function licenseResponse(interaction: Interaction) {
  const reference = option(interaction, "reference");
  if (!reference) return message("Provide an exact public license reference.");
  const result = await verifyPublicLicense(reference);
  if (!result.ok) return unavailable();
  if (result.data.result_code === "not_verifiable") {
    return message("That reference is not verifiable in the public registry.");
  }
  const data = result.data;
  const endorsements = data.endorsements.length
    ? ` Endorsements: ${data.endorsements.join(", ")}.`
    : "";
  return message(
    `**${data.holder_name}** — ${data.status_label}. Reference: ${data.public_reference}. Class: ${data.license_class_label}. Jurisdiction: ${data.jurisdiction_label}. Currently in force: ${data.is_currently_authorized ? "yes" : "no"}.${endorsements}`,
  );
}

export async function handleDiscordInteraction(payload: unknown) {
  const parsed = interactionSchema.safeParse(payload);
  if (!parsed.success) return { body: { code: "invalid_interaction" }, status: 400 };
  if (parsed.data.type === 1) return { body: { type: 1 }, status: 200 };
  if (parsed.data.type !== 2 || !parsed.data.data) {
    return { body: message("This interaction type is not supported."), status: 200 };
  }
  switch (parsed.data.data.name) {
    case "catalogue":
      return { body: await catalogueResponse(parsed.data), status: 200 };
    case "dealer":
      return { body: await dealerResponse(parsed.data), status: 200 };
    case "license":
      return { body: await licenseResponse(parsed.data), status: 200 };
    default:
      return { body: message("That command is not supported."), status: 200 };
  }
}
