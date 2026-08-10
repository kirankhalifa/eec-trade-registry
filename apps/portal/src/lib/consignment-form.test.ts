import { describe, expect, it } from "vitest";

import {
  readCreateConsignmentAgreementForm,
  readDealerConsignmentReportForm,
  readIssueConsignmentForm,
  readReviewConsignmentReportForm,
} from "./consignment-form";

const id = "10000000-0000-4000-8000-000000000001";
const secondId = "10000000-0000-4000-8000-000000000002";

describe("consignment forms", () => {
  it("parses an agreement with an open end date", () => {
    const form = new FormData();
    form.set("owner_party_id", id); form.set("consignee_party_id", secondId);
    form.set("jurisdiction_id", id); form.set("effective_from", "2026-08-10T12:00:00.000Z");
    form.set("effective_until", ""); form.set("terms_summary", "Recorded terms");
    form.set("reason", "Approved agreement");
    expect(readCreateConsignmentAgreementForm(form).success).toBe(true);
  });

  it("requires a positive issue quantity", () => {
    const form = new FormData();
    form.set("agreement_id", id); form.set("source_inventory_account_id", secondId);
    form.set("quantity", "0"); form.set("reason", "Issue stock");
    expect(readIssueConsignmentForm(form).success).toBe(false);
  });

  it("accepts a review without a return destination", () => {
    const form = new FormData();
    form.set("id", id); form.set("expected_version", "1");
    form.set("return_inventory_account_id", ""); form.set("reason", "Evidence reviewed");
    expect(readReviewConsignmentReportForm(form).success).toBe(true);
  });

  it("rejects negative dealer observations", () => {
    const form = new FormData();
    form.set("consignment_issue_id", id); form.set("quantity_sold", "1");
    form.set("quantity_returned", "0"); form.set("quantity_lost", "0");
    form.set("quantity_damaged", "0"); form.set("observed_on_hand", "-1");
    form.set("report_notes", "Counted"); form.set("reason", "Periodic report");
    expect(readDealerConsignmentReportForm(form).success).toBe(false);
  });
});
