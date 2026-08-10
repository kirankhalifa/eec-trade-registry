import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";

const optionSchema = z.object({ id: z.guid(), display_name: z.string() });
const capabilitiesSchema = z.object({
  can_manage_cases: z.boolean(), can_manage_inspections: z.boolean(),
  can_manage_evidence: z.boolean(), can_record_findings: z.boolean(),
  can_recommend_actions: z.boolean(), can_approve_actions: z.boolean(),
  can_manage_appeals: z.boolean(),
});
const caseSummarySchema = z.object({
  id: z.guid(), public_reference: z.string(), case_type: z.string(),
  status: z.string(), confidentiality_level: z.string(),
  subject_party_id: z.guid().nullable(), subject_name: z.string().nullable(),
  related_record_type: z.string(), related_record_id: z.guid().nullable(),
  summary: z.string(), assigned_actor_id: z.guid().nullable(),
  assigned_actor_name: z.string().nullable(), opened_at: z.string(),
  version: z.coerce.number().int().positive().safe(),
  allegation_count: z.coerce.number().int(), finding_count: z.coerce.number().int(),
  pending_action_count: z.coerce.number().int(), open_appeal_count: z.coerce.number().int(),
});
const workspaceSchema = z.object({
  capabilities: capabilitiesSchema,
  case_types: z.array(optionSchema.extend({ code: z.string() })),
  parties: z.array(optionSchema), staff_actors: z.array(optionSchema),
  related_records: z.array(z.object({ record_type: z.string(), id: z.guid(), label: z.string() })),
  cases: z.array(caseSummarySchema),
});

const detailSchema = caseSummarySchema.omit({
  allegation_count: true, finding_count: true, pending_action_count: true, open_appeal_count: true,
}).extend({
  resolution: z.string().nullable(), capabilities: capabilitiesSchema,
  violation_types: z.array(optionSchema),
  action_types: z.array(optionSchema.extend({ effect_mode: z.literal("record_only") })),
  parties: z.array(optionSchema), staff_actors: z.array(optionSchema),
  inspections: z.array(z.object({
    id: z.guid(), public_reference: z.string(), status: z.enum(["planned", "completed", "cancelled"]),
    scheduled_for: z.string().nullable(), location_summary: z.string(), scope_summary: z.string(),
    observations: z.string().nullable(), completed_at: z.string().nullable(),
    version: z.coerce.number().int().positive().safe(),
  })),
  allegations: z.array(z.object({ id: z.guid(), violation_type: z.string(), status: z.literal("alleged"), statement: z.string(), recorded_at: z.string() })),
  findings: z.array(z.object({ id: z.guid(), allegation_id: z.guid().nullable(), outcome: z.string(), rationale: z.string(), decided_at: z.string() })),
  evidence: z.array(z.object({ id: z.guid(), inspection_id: z.guid().nullable(), evidence_type: z.string(), confidentiality_level: z.string(), evidence_reference: z.string(), description: z.string(), collected_at: z.string() })),
  actions: z.array(z.object({
    id: z.guid(), public_reference: z.string(), action_type: z.string(), effect_mode: z.literal("record_only"),
    subject_party_id: z.guid().nullable(), related_record_type: z.string(), related_record_id: z.guid().nullable(),
    status: z.enum(["recommended", "approved", "declined", "voided"]), recommendation: z.string(),
    recommended_at: z.string(), review_reason: z.string().nullable(), version: z.coerce.number().int().positive().safe(),
  })),
  appeals: z.array(z.object({
    id: z.guid(), public_reference: z.string(), compliance_action_id: z.guid(), appellant_party_id: z.guid(),
    appellant_name: z.string(), status: z.enum(["filed", "decided", "withdrawn"]), filing_summary: z.string(),
    filed_at: z.string(), outcome: z.string().nullable(), decision_reason: z.string().nullable(),
    version: z.coerce.number().int().positive().safe(),
  })),
  events: z.array(z.object({ event_type: z.string(), previous_state: z.unknown().nullable(), new_state: z.unknown(), reason: z.string(), occurred_at: z.string() })),
});

export type ComplianceWorkspace = z.infer<typeof workspaceSchema>;
export type ComplianceCaseDetail = z.infer<typeof detailSchema>;
type Result<T> = { ok: true; data: T } | { ok: false; code: "access_denied" | "not_found" | "invalid_response" | "query_failed" };

async function query<T>(client: SupabaseClient, rpc: string, schema: z.ZodType<T>, parameters?: Record<string, unknown>): Promise<Result<T>> {
  const { data, error } = await client.rpc(rpc, parameters);
  if (error) {
    console.error(`[staff-compliance:query] ${error.message}`);
    if (error.code === "P0002") return { ok: false, code: "not_found" };
    return { ok: false, code: error.code === "42501" || error.message.includes("permission_denied") ? "access_denied" : "query_failed" };
  }
  const parsed = schema.safeParse(data);
  if (!parsed.success) { console.error("[staff-compliance:query] Unexpected Supabase response."); return { ok: false, code: "invalid_response" }; }
  return { ok: true, data: parsed.data };
}
export function getStaffComplianceWorkspace(client: SupabaseClient) {
  return query(client, "get_staff_compliance_workspace", workspaceSchema);
}
export function getStaffComplianceCase(client: SupabaseClient, id: string) {
  return query(client, "get_staff_compliance_case", detailSchema, { p_compliance_case_id: id });
}
