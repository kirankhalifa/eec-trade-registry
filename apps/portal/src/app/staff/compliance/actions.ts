"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";

import {
  readComplianceAllegationForm, readComplianceAppealForm, readComplianceEvidenceForm,
  readComplianceFindingForm, readCreateComplianceCaseForm, readCreateComplianceInspectionForm,
  readDecideComplianceAppealForm, readFinishComplianceInspectionForm,
  readRecommendComplianceActionForm, readReviewComplianceActionForm,
  readTransitionComplianceCaseForm, splitRelated,
} from "@/lib/compliance-form";
import { createServerSupabaseClient } from "@/lib/supabase-server";

const root = "/staff/compliance";
function casePath(value: FormDataEntryValue | null) { return typeof value === "string" && z.guid().safeParse(value).success ? `${root}/${value}` : root; }
function destination(path: string, key: "error" | "notice", value: string) { return `${path}?${new URLSearchParams({ [key]: value }).toString()}`; }
function errorPath(path: string, error: { code?: string; message: string }) {
  console.error(`[staff-compliance:mutation] ${error.code ?? "unknown"}`);
  if (error.code === "40001" || error.message.includes("version_conflict")) return destination(path, "error", "conflict");
  if (error.code === "42501" || error.message.includes("permission_denied")) return destination(path, "error", "access_denied");
  if (error.code === "P0002" || error.message.includes("not_found")) return destination(path, "error", "not_found");
  if (error.code === "23505" || error.message.includes("already_filed")) return destination(path, "error", "duplicate_appeal");
  if (error.code === "22023" || error.code === "23514") return destination(path, "error", "invalid_input");
  return destination(path, "error", "save_failed");
}
async function client() { const value = await createServerSupabaseClient(); const { data, error } = await value.auth.getClaims(); return !error && typeof data?.claims?.sub === "string" ? value : null; }
function refresh(path: string) { revalidatePath(root); revalidatePath(path); revalidatePath("/staff"); }

export async function createComplianceCaseAction(formData: FormData) {
  const parsed = readCreateComplianceCaseForm(formData); if (!parsed.success) redirect(destination(root, "error", "invalid_input"));
  const supabase = await client(); if (!supabase) redirect("/staff/login"); const input = parsed.data; const related = splitRelated(input.related);
  const { data, error } = await supabase.rpc("staff_create_compliance_case", { p_assigned_actor_id: input.assignedActorId, p_case_type_id: input.caseTypeId, p_confidentiality_level: input.confidentialityLevel, p_reason: input.reason, p_related_record_id: related.id, p_related_record_type: related.type, p_request_id: crypto.randomUUID(), p_subject_party_id: input.subjectPartyId, p_summary: input.summary });
  if (error) redirect(errorPath(root, error)); const id = Array.isArray(data) ? data[0]?.compliance_case_id : null; refresh(root); redirect(destination(typeof id === "string" ? `${root}/${id}` : root, "notice", "case_created"));
}
export async function transitionComplianceCaseAction(formData: FormData) {
  const path = casePath(formData.get("case_id")); const parsed = readTransitionComplianceCaseForm(formData); if (!parsed.success) redirect(destination(path, "error", "invalid_input")); const supabase = await client(); if (!supabase) redirect("/staff/login"); const input = parsed.data;
  const { error } = await supabase.rpc("staff_transition_compliance_case", { p_assigned_actor_id: input.assignedActorId, p_compliance_case_id: input.caseId, p_expected_version: input.expectedVersion, p_reason: input.reason, p_request_id: crypto.randomUUID(), p_resolution: input.resolution || null, p_status: input.status }); if (error) redirect(errorPath(path, error)); refresh(path); redirect(destination(path, "notice", "case_transitioned"));
}
export async function createComplianceInspectionAction(formData: FormData) {
  const path = casePath(formData.get("case_id")); const parsed = readCreateComplianceInspectionForm(formData); if (!parsed.success) redirect(destination(path, "error", "invalid_input")); const supabase = await client(); if (!supabase) redirect("/staff/login"); const input = parsed.data;
  const { error } = await supabase.rpc("staff_create_compliance_inspection", { p_compliance_case_id: input.caseId, p_location_summary: input.locationSummary, p_reason: input.reason, p_request_id: crypto.randomUUID(), p_scheduled_for: input.scheduledFor, p_scope_summary: input.scopeSummary }); if (error) redirect(errorPath(path, error)); refresh(path); redirect(destination(path, "notice", "inspection_created"));
}
export async function finishComplianceInspectionAction(formData: FormData) {
  const path = casePath(formData.get("case_id")); const parsed = readFinishComplianceInspectionForm(formData); if (!parsed.success) redirect(destination(path, "error", "invalid_input")); const supabase = await client(); if (!supabase) redirect("/staff/login"); const input = parsed.data;
  const { error } = await supabase.rpc("staff_finish_compliance_inspection", { p_expected_version: input.expectedVersion, p_inspection_id: input.id, p_observations: input.observations || null, p_reason: input.reason, p_request_id: crypto.randomUUID(), p_status: input.status }); if (error) redirect(errorPath(path, error)); refresh(path); redirect(destination(path, "notice", "inspection_finished"));
}
export async function recordComplianceAllegationAction(formData: FormData) {
  const path = casePath(formData.get("case_id")); const parsed = readComplianceAllegationForm(formData); if (!parsed.success) redirect(destination(path, "error", "invalid_input")); const supabase = await client(); if (!supabase) redirect("/staff/login"); const input = parsed.data;
  const { error } = await supabase.rpc("staff_record_compliance_allegation", { p_compliance_case_id: input.caseId, p_reason: input.reason, p_request_id: crypto.randomUUID(), p_statement: input.statement, p_violation_type_id: input.violationTypeId }); if (error) redirect(errorPath(path, error)); refresh(path); redirect(destination(path, "notice", "allegation"));
}
export async function recordComplianceEvidenceAction(formData: FormData) {
  const path = casePath(formData.get("case_id")); const parsed = readComplianceEvidenceForm(formData); if (!parsed.success) redirect(destination(path, "error", "invalid_input")); const supabase = await client(); if (!supabase) redirect("/staff/login"); const input = parsed.data;
  const { error } = await supabase.rpc("staff_record_compliance_evidence", { p_collected_at: input.collectedAt, p_compliance_case_id: input.caseId, p_confidentiality_level: input.confidentialityLevel, p_description: input.description, p_evidence_reference: input.evidenceReference, p_evidence_type: input.evidenceType, p_inspection_id: input.inspectionId, p_reason: input.reason, p_request_id: crypto.randomUUID() }); if (error) redirect(errorPath(path, error)); refresh(path); redirect(destination(path, "notice", "evidence"));
}
export async function recordComplianceFindingAction(formData: FormData) {
  const path = casePath(formData.get("case_id")); const parsed = readComplianceFindingForm(formData); if (!parsed.success) redirect(destination(path, "error", "invalid_input")); const supabase = await client(); if (!supabase) redirect("/staff/login"); const input = parsed.data;
  const { error } = await supabase.rpc("staff_record_compliance_finding", { p_allegation_id: input.allegationId, p_compliance_case_id: input.caseId, p_outcome: input.outcome, p_rationale: input.rationale, p_reason: input.reason, p_request_id: crypto.randomUUID() }); if (error) redirect(errorPath(path, error)); refresh(path); redirect(destination(path, "notice", "finding"));
}
export async function recommendComplianceActionAction(formData: FormData) {
  const path = casePath(formData.get("case_id")); const parsed = readRecommendComplianceActionForm(formData); if (!parsed.success) redirect(destination(path, "error", "invalid_input")); const supabase = await client(); if (!supabase) redirect("/staff/login"); const input = parsed.data; const related = splitRelated(input.related);
  const { error } = await supabase.rpc("staff_recommend_compliance_action", { p_action_type_id: input.actionTypeId, p_compliance_case_id: input.caseId, p_reason: input.reason, p_recommendation: input.recommendation, p_related_record_id: related.id, p_related_record_type: related.type, p_request_id: crypto.randomUUID(), p_subject_party_id: input.subjectPartyId }); if (error) redirect(errorPath(path, error)); refresh(path); redirect(destination(path, "notice", "action_recommended"));
}
export async function reviewComplianceActionAction(formData: FormData) {
  const path = casePath(formData.get("case_id")); const parsed = readReviewComplianceActionForm(formData); if (!parsed.success) redirect(destination(path, "error", "invalid_input")); const supabase = await client(); if (!supabase) redirect("/staff/login"); const input = parsed.data;
  const { error } = await supabase.rpc("staff_review_compliance_action", { p_compliance_action_id: input.id, p_expected_version: input.expectedVersion, p_reason: input.reason, p_request_id: crypto.randomUUID(), p_status: input.status }); if (error) redirect(errorPath(path, error)); refresh(path); redirect(destination(path, "notice", "action_reviewed"));
}
export async function recordComplianceAppealAction(formData: FormData) {
  const path = casePath(formData.get("case_id")); const parsed = readComplianceAppealForm(formData); if (!parsed.success) redirect(destination(path, "error", "invalid_input")); const supabase = await client(); if (!supabase) redirect("/staff/login"); const input = parsed.data;
  const { error } = await supabase.rpc("staff_record_compliance_appeal", { p_appellant_party_id: input.appellantPartyId, p_compliance_action_id: input.actionId, p_filing_summary: input.filingSummary, p_reason: input.reason, p_request_id: crypto.randomUUID() }); if (error) redirect(errorPath(path, error)); refresh(path); redirect(destination(path, "notice", "appeal_filed"));
}
export async function decideComplianceAppealAction(formData: FormData) {
  const path = casePath(formData.get("case_id")); const parsed = readDecideComplianceAppealForm(formData); if (!parsed.success) redirect(destination(path, "error", "invalid_input")); const supabase = await client(); if (!supabase) redirect("/staff/login"); const input = parsed.data;
  const { error } = await supabase.rpc("staff_decide_compliance_appeal", { p_appeal_id: input.id, p_decision_reason: input.decisionReason, p_expected_version: input.expectedVersion, p_outcome: input.status === "decided" ? input.outcome : null, p_reason: input.reason, p_request_id: crypto.randomUUID(), p_status: input.status }); if (error) redirect(errorPath(path, error)); refresh(path); redirect(destination(path, "notice", "appeal_decided"));
}
