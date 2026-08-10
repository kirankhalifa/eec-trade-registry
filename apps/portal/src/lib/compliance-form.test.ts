import { describe, expect, it } from "vitest";
import { readCreateComplianceCaseForm, readComplianceFindingForm, readDecideComplianceAppealForm, splitRelated } from "./compliance-form";
const id = "10000000-0000-4000-8000-000000000001";
describe("compliance forms", () => {
  it("parses a policy-neutral case", () => { const form = new FormData(); form.set("case_type_id", id); form.set("subject_party_id", ""); form.set("related", "none"); form.set("confidentiality_level", "restricted"); form.set("summary", "Review the recorded matter."); form.set("assigned_actor_id", ""); form.set("reason", "Open for triage"); expect(readCreateComplianceCaseForm(form).success).toBe(true); });
  it("splits a typed related record", () => expect(splitRelated(`license:${id}`)).toEqual({ type: "license", id }));
  it("keeps finding outcomes explicit", () => { const form = new FormData(); form.set("case_id", id); form.set("allegation_id", ""); form.set("outcome", "substantiated"); form.set("rationale", "Evidence supports the finding."); form.set("reason", "Record decision"); expect(readComplianceFindingForm(form).success).toBe(true); form.set("outcome", "guilty"); expect(readComplianceFindingForm(form).success).toBe(false); });
  it("requires a bounded appeal outcome", () => { const form = new FormData(); form.set("case_id", id); form.set("id", id); form.set("expected_version", "1"); form.set("status", "decided"); form.set("outcome", "affirmed"); form.set("decision_reason", "Record-only decision."); form.set("reason", "Complete review"); expect(readDecideComplianceAppealForm(form).success).toBe(true); });
});
