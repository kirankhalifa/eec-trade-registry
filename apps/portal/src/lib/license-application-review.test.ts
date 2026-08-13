import { describe, expect, it } from "vitest";

import { parseLicenseApplicationReviewWorkspace } from "./license-application-review";

describe("license application review workspace", () => {
  it("keeps requested endorsements attached to the review record", () => {
    const parsed = parseLicenseApplicationReviewWorkspace({
      applications: [{
        applicant_name: "Solitude Tailor",
        class_name: "Tailoring",
        contact_label: "tailor-discord",
        existing_license_reference: null,
        id: "10000000-0000-4000-8000-000000000001",
        issued_license_reference: null,
        jurisdiction_name: "Solitude",
        reference: "APP-001",
        requested_endorsements: [{ code: "textiles", label: "Textiles" }],
        review_reason: null,
        reviewed_at: null,
        statement: "We wish to trade tailored goods.",
        status: "submitted",
        submitted_at: "2026-08-13T12:00:00Z",
        type: "new",
        version: 1,
      }],
      generated_at: "2026-08-13T12:00:00Z",
      parties: [],
    });
    expect(parsed.success).toBe(true);
    if (parsed.success) expect(parsed.data.applications[0].requested_endorsements[0].code).toBe("textiles");
  });
});
