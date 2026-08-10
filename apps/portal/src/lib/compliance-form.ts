import { z } from "zod";

const reason = z.string().trim().min(1).max(500);
const caseId = z.guid();
const command = z.object({ caseId, id: z.guid(), expectedVersion: z.coerce.number().int().positive().safe(), reason });
const relatedPattern = /^(none|(?:license|dealer_authorization|order|stock_transfer|serialized_asset|consignment_issue):[0-9a-f-]{36})$/i;
const createCaseSchema = z.object({
  caseTypeId: z.guid(), subjectPartyId: z.guid().nullable(), related: z.string().regex(relatedPattern),
  confidentialityLevel: z.enum(["internal", "restricted"]), summary: z.string().trim().min(1).max(4000),
  assignedActorId: z.guid().nullable(), reason,
});
const transitionSchema = command.extend({ status: z.enum(["triage", "investigating", "awaiting_response", "deciding", "resolved", "no_action", "closed", "reopened"]), assignedActorId: z.guid().nullable(), resolution: z.string().trim().max(4000) });
const inspectionSchema = z.object({ caseId, scheduledFor: z.string().nullable(), locationSummary: z.string().trim().max(1000), scopeSummary: z.string().trim().min(1).max(4000), reason });
const finishInspectionSchema = command.extend({ status: z.enum(["completed", "cancelled"]), observations: z.string().trim().max(4000) });
const allegationSchema = z.object({ caseId, violationTypeId: z.guid(), statement: z.string().trim().min(1).max(4000), reason });
const evidenceSchema = z.object({ caseId, inspectionId: z.guid().nullable(), evidenceType: z.enum(["document", "image", "statement", "system_record", "other"]), confidentialityLevel: z.enum(["internal", "restricted"]), evidenceReference: z.string().trim().min(1).max(500), description: z.string().trim().min(1).max(4000), collectedAt: z.string().datetime({ offset: true }), reason });
const findingSchema = z.object({ caseId, allegationId: z.guid().nullable(), outcome: z.enum(["substantiated", "not_substantiated", "inconclusive"]), rationale: z.string().trim().min(1).max(4000), reason });
const actionSchema = z.object({ caseId, actionTypeId: z.guid(), subjectPartyId: z.guid().nullable(), related: z.string().regex(relatedPattern), recommendation: z.string().trim().min(1).max(4000), reason });
const reviewActionSchema = command.extend({ status: z.enum(["approved", "declined", "voided"]) });
const appealSchema = z.object({ caseId, actionId: z.guid(), appellantPartyId: z.guid(), filingSummary: z.string().trim().min(1).max(4000), reason });
const decideAppealSchema = command.extend({ status: z.enum(["decided", "withdrawn"]), outcome: z.enum(["affirmed", "varied", "remanded", "reversed"]).nullable(), decisionReason: z.string().trim().min(1).max(4000) });

function nullable(value: FormDataEntryValue | null) { return typeof value === "string" && value.trim() ? value : null; }
function timestamp(value: FormDataEntryValue | null) { if (typeof value !== "string" || !value.trim()) return null; const date = new Date(value); return Number.isNaN(date.valueOf()) ? value : date.toISOString(); }
function base(formData: FormData) { return { caseId: formData.get("case_id"), id: formData.get("id"), expectedVersion: formData.get("expected_version"), reason: formData.get("reason") }; }
export function splitRelated(value: string) { if (value === "none") return { type: "none", id: null }; const [type, id] = value.split(":"); return { type, id }; }
export function readCreateComplianceCaseForm(formData: FormData) { return createCaseSchema.safeParse({ caseTypeId: formData.get("case_type_id"), subjectPartyId: nullable(formData.get("subject_party_id")), related: formData.get("related"), confidentialityLevel: formData.get("confidentiality_level"), summary: formData.get("summary"), assignedActorId: nullable(formData.get("assigned_actor_id")), reason: formData.get("reason") }); }
export function readTransitionComplianceCaseForm(formData: FormData) { return transitionSchema.safeParse({ ...base(formData), status: formData.get("status"), assignedActorId: nullable(formData.get("assigned_actor_id")), resolution: formData.get("resolution") }); }
export function readCreateComplianceInspectionForm(formData: FormData) { return inspectionSchema.safeParse({ caseId: formData.get("case_id"), scheduledFor: timestamp(formData.get("scheduled_for")), locationSummary: formData.get("location_summary"), scopeSummary: formData.get("scope_summary"), reason: formData.get("reason") }); }
export function readFinishComplianceInspectionForm(formData: FormData) { return finishInspectionSchema.safeParse({ ...base(formData), status: formData.get("status"), observations: formData.get("observations") }); }
export function readComplianceAllegationForm(formData: FormData) { return allegationSchema.safeParse({ caseId: formData.get("case_id"), violationTypeId: formData.get("violation_type_id"), statement: formData.get("statement"), reason: formData.get("reason") }); }
export function readComplianceEvidenceForm(formData: FormData) { return evidenceSchema.safeParse({ caseId: formData.get("case_id"), inspectionId: nullable(formData.get("inspection_id")), evidenceType: formData.get("evidence_type"), confidentialityLevel: formData.get("confidentiality_level"), evidenceReference: formData.get("evidence_reference"), description: formData.get("description"), collectedAt: timestamp(formData.get("collected_at")), reason: formData.get("reason") }); }
export function readComplianceFindingForm(formData: FormData) { return findingSchema.safeParse({ caseId: formData.get("case_id"), allegationId: nullable(formData.get("allegation_id")), outcome: formData.get("outcome"), rationale: formData.get("rationale"), reason: formData.get("reason") }); }
export function readRecommendComplianceActionForm(formData: FormData) { return actionSchema.safeParse({ caseId: formData.get("case_id"), actionTypeId: formData.get("action_type_id"), subjectPartyId: nullable(formData.get("subject_party_id")), related: formData.get("related"), recommendation: formData.get("recommendation"), reason: formData.get("reason") }); }
export function readReviewComplianceActionForm(formData: FormData) { return reviewActionSchema.safeParse({ ...base(formData), status: formData.get("status") }); }
export function readComplianceAppealForm(formData: FormData) { return appealSchema.safeParse({ caseId: formData.get("case_id"), actionId: formData.get("action_id"), appellantPartyId: formData.get("appellant_party_id"), filingSummary: formData.get("filing_summary"), reason: formData.get("reason") }); }
export function readDecideComplianceAppealForm(formData: FormData) { return decideAppealSchema.safeParse({ ...base(formData), status: formData.get("status"), outcome: nullable(formData.get("outcome")), decisionReason: formData.get("decision_reason") }); }
