import { PDFDocument } from "pdf-lib";
import { describe, expect, it } from "vitest";

import { buildOfficialPdf } from "@/lib/official-pdf";

describe("official PDF projection", () => {
  it("renders a readable PDF from an immutable source snapshot", async () => {
    const bytes = await buildOfficialPdf({
      checksum_sha256: "a".repeat(64), document_type: "license_certificate",
      generated_at: "2026-08-10T12:00:00Z", public_reference: "EEC-DOC-1001",
      snapshot_payload: { document_title: "East Empire Company License", holder_name: "Aurelion Earandil", endorsements: ["Tailoring"] },
      source_record_type: "license", source_version: 2,
    });
    expect(new TextDecoder().decode(bytes.slice(0, 5))).toBe("%PDF-");
    const pdf = await PDFDocument.load(bytes);
    expect(pdf.getPageCount()).toBeGreaterThanOrEqual(1);
    expect(pdf.getTitle()).toBe("East Empire Company License");
  });
});
