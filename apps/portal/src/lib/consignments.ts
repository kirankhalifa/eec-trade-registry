import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";

const partySchema = z.object({ id: z.guid(), display_name: z.string() });
const jurisdictionSchema = z.object({ id: z.guid(), display_name: z.string() });
const accountSchema = z.object({
  id: z.guid(),
  item_id: z.guid(),
  item_code: z.string(),
  owner_party_id: z.guid(),
  warehouse_id: z.guid(),
  warehouse_name: z.string(),
  location_name: z.string(),
});
const sourceAccountSchema = accountSchema.extend({
  item_name: z.string(),
  available: z.coerce.number(),
});
const agreementSchema = z.object({
  id: z.guid(),
  public_reference: z.string(),
  version: z.coerce.number().int().positive().safe(),
  status: z.enum(["active", "suspended", "closed"]),
  owner_party_id: z.guid(),
  owner_name: z.string(),
  consignee_party_id: z.guid(),
  consignee_name: z.string(),
  jurisdiction_name: z.string(),
  effective_from: z.string(),
  effective_until: z.string().nullable(),
  terms_summary: z.string(),
});
const issueSchema = z.object({
  id: z.guid(),
  public_reference: z.string(),
  version: z.coerce.number().int().positive().safe(),
  status: z.enum(["active", "closed"]),
  agreement_id: z.guid(),
  agreement_reference: z.string(),
  item_id: z.guid(),
  item_code: z.string(),
  item_name: z.string(),
  consignee_name: z.string(),
  quantity_issued: z.coerce.number(),
  quantity_sold: z.coerce.number(),
  quantity_returned: z.coerce.number(),
  quantity_outstanding: z.coerce.number(),
  issued_at: z.string(),
});
const reportSchema = z.object({
  id: z.guid(),
  public_reference: z.string(),
  version: z.coerce.number().int().positive().safe(),
  status: z.enum(["submitted", "accepted", "rejected"]),
  consignment_issue_id: z.guid(),
  issue_reference: z.string(),
  item_id: z.guid(),
  item_code: z.string(),
  consignee_name: z.string(),
  quantity_sold: z.coerce.number(),
  quantity_returned: z.coerce.number(),
  quantity_lost: z.coerce.number(),
  quantity_damaged: z.coerce.number(),
  observed_on_hand: z.coerce.number(),
  report_notes: z.string(),
  submitted_at: z.string(),
});
const staffWorkspaceSchema = z.object({
  capabilities: z.object({
    can_manage_agreements: z.boolean(),
    can_issue: z.boolean(),
    can_review: z.boolean(),
    can_receive_returns: z.boolean(),
  }),
  owners: z.array(partySchema),
  consignees: z.array(partySchema),
  jurisdictions: z.array(jurisdictionSchema),
  source_accounts: z.array(sourceAccountSchema),
  return_accounts: z.array(accountSchema),
  agreements: z.array(agreementSchema),
  issues: z.array(issueSchema),
  reports: z.array(reportSchema),
});

const dealerReportSchema = z.object({
  public_reference: z.string(),
  status: z.enum(["submitted", "accepted", "rejected"]),
  quantity_sold: z.coerce.number(),
  quantity_returned: z.coerce.number(),
  quantity_lost: z.coerce.number(),
  quantity_damaged: z.coerce.number(),
  observed_on_hand: z.coerce.number(),
  submitted_at: z.string(),
});
const dealerIssueSchema = issueSchema.omit({
  agreement_id: true,
  item_id: true,
}).extend({
  consignee_party_id: z.guid(),
  reports: z.array(dealerReportSchema),
});
const dealerWorkspaceSchema = z.object({ issues: z.array(dealerIssueSchema) });

export type StaffConsignmentWorkspace = z.infer<typeof staffWorkspaceSchema>;
export type DealerConsignmentWorkspace = z.infer<typeof dealerWorkspaceSchema>;
type QueryError = "access_denied" | "invalid_response" | "query_failed";
type QueryResult<T> = { ok: true; data: T } | { ok: false; code: QueryError };

async function readWorkspace<T>(
  client: SupabaseClient,
  rpc: "get_staff_consignment_workspace" | "get_dealer_consignments",
  schema: z.ZodType<T>,
  surface: string,
): Promise<QueryResult<T>> {
  const { data, error } = await client.rpc(rpc);
  if (error) {
    console.error(`[${surface}:workspace] ${error.message}`);
    return {
      ok: false,
      code: error.message.includes("permission_denied") ||
        error.message.includes("scope_denied") ||
        error.message.includes("authentication_required")
        ? "access_denied"
        : "query_failed",
    };
  }
  const parsed = schema.safeParse(data);
  if (!parsed.success) {
    console.error(`[${surface}:workspace] Unexpected Supabase response.`);
    return { ok: false, code: "invalid_response" };
  }
  return { ok: true, data: parsed.data };
}

export function getStaffConsignmentWorkspace(client: SupabaseClient) {
  return readWorkspace(client, "get_staff_consignment_workspace", staffWorkspaceSchema, "staff-consignments");
}

export function getDealerConsignmentWorkspace(client: SupabaseClient) {
  return readWorkspace(client, "get_dealer_consignments", dealerWorkspaceSchema, "dealer-consignments");
}
