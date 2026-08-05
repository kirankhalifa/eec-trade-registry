import { describe, expect, it } from "vitest";

import { escapeDiscordMentions, renderNotificationTemplate } from "./integration-template";

describe("integration notification templates", () => {
  it("substitutes scalar fields without serializing private objects", () => {
    expect(
      renderNotificationTemplate("Order {{reference}}: {{quantity}} {{private_data}}", {
        private_data: { secret: true },
        quantity: 4,
        reference: "EST-42",
      }),
    ).toBe("Order EST-42: 4 ");
  });

  it("neutralizes Discord mentions and limits output length", () => {
    expect(escapeDiscordMentions("@everyone @here")).toBe("@\u200beveryone @\u200bhere");
    expect(renderNotificationTemplate("{{value}}", { value: "x".repeat(2_000) })).toHaveLength(1_900);
  });
});
