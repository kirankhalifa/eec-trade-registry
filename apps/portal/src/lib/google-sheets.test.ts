import { describe, expect, it } from "vitest";

import { buildSheetMatrix, checksumSheetMatrix } from "./google-sheets";

describe("Google Sheets projection snapshots", () => {
  it("builds metadata, fixed headers, and absolute source links", () => {
    const matrix = buildSheetMatrix(
      "public_catalogue",
      [
        { key: "item_code", label: "Item code" },
        { key: "source_url", label: "Source" },
      ],
      [{ item_code: "ORE-1", source_url: "/catalogue/ore-1" }],
      "2026-08-05T12:00:00.000Z",
      "https://registry.example.test",
    );
    expect(matrix).toEqual([
      ["Source", "https://registry.example.test/"],
      ["Projection", "public_catalogue"],
      ["Generated at", "2026-08-05T12:00:00.000Z"],
      [],
      ["Item code", "Source"],
      ["ORE-1", "https://registry.example.test/catalogue/ore-1"],
    ]);
  });

  it("produces deterministic checksums and enforces row limits", () => {
    expect(checksumSheetMatrix([["a", 1]])).toBe(checksumSheetMatrix([["a", 1]]));
    expect(checksumSheetMatrix([["a", 1]])).not.toBe(checksumSheetMatrix([["a", 2]]));
    expect(() =>
      buildSheetMatrix("public_catalogue", [{ key: "a", label: "A" }], Array.from({ length: 20_001 }, () => ({})), "now", "https://example.test"),
    ).toThrow("sheet_row_limit_exceeded");
  });
});
