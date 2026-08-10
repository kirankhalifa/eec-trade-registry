"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import {
  readConsignmentAgreementStatusForm,
  readCreateConsignmentAgreementForm,
  readIssueConsignmentForm,
  readReviewConsignmentReportForm,
} from "@/lib/consignment-form";
import { createServerSupabaseClient } from "@/lib/supabase-server";

const path = "/staff/consignments";
function destination(key: "error" | "notice", value: string) {
  return `${path}?${new URLSearchParams({ [key]: value }).toString()}`;
}
function errorPath(error: { code?: string; message: string }) {
  console.error(`[staff-consignments:mutation] ${error.code ?? "unknown"}`);
  if (error.code === "40001" || error.message.includes("version_conflict")) return destination("error", "conflict");
  if (error.code === "42501" || error.message.includes("permission_denied") || error.message.includes("destination_denied")) return destination("error", "access_denied");
  if (error.code === "P0002" || error.message.includes("not_found")) return destination("error", "not_found");
  if (error.code === "23505" || error.message.includes("already_pending")) return destination("error", "duplicate_report");
  if (error.message.includes("stock_unavailable") || error.message.includes("stock_insufficient")) return destination("error", "insufficient_stock");
  if (error.message.includes("exception_review")) return destination("error", "exception_review");
  if (error.message.includes("observation_mismatch")) return destination("error", "observation_mismatch");
  if (error.code === "22023" || error.code === "23514") return destination("error", "invalid_input");
  return destination("error", "save_failed");
}
async function verifiedClient() {
  const client = await createServerSupabaseClient();
  const { data, error } = await client.auth.getClaims();
  return !error && typeof data?.claims?.sub === "string" ? client : null;
}
function refresh() {
  revalidatePath(path); revalidatePath("/staff/inventory"); revalidatePath("/dealer/consignments");
}

export async function createConsignmentAgreementAction(formData: FormData) {
  const parsed = readCreateConsignmentAgreementForm(formData);
  if (!parsed.success) redirect(destination("error", "invalid_input"));
  const client = await verifiedClient(); if (!client) redirect("/staff/login");
  const input = parsed.data;
  const { error } = await client.rpc("staff_create_consignment_agreement", {
    p_consignee_party_id: input.consigneePartyId,
    p_effective_from: input.effectiveFrom,
    p_effective_until: input.effectiveUntil,
    p_jurisdiction_id: input.jurisdictionId,
    p_owner_party_id: input.ownerPartyId,
    p_reason: input.reason,
    p_request_id: crypto.randomUUID(),
    p_terms_summary: input.termsSummary,
  });
  if (error) redirect(errorPath(error)); refresh();
  redirect(destination("notice", "agreement_created"));
}

export async function changeConsignmentAgreementStatusAction(formData: FormData) {
  const parsed = readConsignmentAgreementStatusForm(formData);
  if (!parsed.success) redirect(destination("error", "invalid_input"));
  const client = await verifiedClient(); if (!client) redirect("/staff/login");
  const input = parsed.data;
  const { error } = await client.rpc("staff_change_consignment_agreement_status", {
    p_agreement_id: input.id, p_expected_version: input.expectedVersion,
    p_reason: input.reason, p_request_id: crypto.randomUUID(), p_status: input.status,
  });
  if (error) redirect(errorPath(error)); refresh();
  redirect(destination("notice", "agreement_status"));
}

export async function issueConsignmentStockAction(formData: FormData) {
  const parsed = readIssueConsignmentForm(formData);
  if (!parsed.success) redirect(destination("error", "invalid_input"));
  const client = await verifiedClient(); if (!client) redirect("/staff/login");
  const input = parsed.data;
  const { error } = await client.rpc("staff_issue_consignment_stock", {
    p_agreement_id: input.agreementId, p_quantity: input.quantity,
    p_reason: input.reason, p_request_id: crypto.randomUUID(),
    p_source_inventory_account_id: input.sourceInventoryAccountId,
  });
  if (error) redirect(errorPath(error)); refresh();
  redirect(destination("notice", "issued"));
}

async function reviewReport(formData: FormData, accept: boolean) {
  const parsed = readReviewConsignmentReportForm(formData);
  if (!parsed.success) redirect(destination("error", "invalid_input"));
  const client = await verifiedClient(); if (!client) redirect("/staff/login");
  const input = parsed.data;
  const request = accept
    ? client.rpc("staff_accept_consignment_report", {
        p_consignment_report_id: input.id, p_expected_version: input.expectedVersion,
        p_reason: input.reason, p_request_id: crypto.randomUUID(),
        p_return_inventory_account_id: input.returnInventoryAccountId,
      })
    : client.rpc("staff_reject_consignment_report", {
        p_consignment_report_id: input.id, p_expected_version: input.expectedVersion,
        p_reason: input.reason, p_request_id: crypto.randomUUID(),
      });
  const { error } = await request;
  if (error) redirect(errorPath(error)); refresh();
  redirect(destination("notice", accept ? "report_accepted" : "report_rejected"));
}
export async function acceptConsignmentReportAction(formData: FormData) { return reviewReport(formData, true); }
export async function rejectConsignmentReportAction(formData: FormData) { return reviewReport(formData, false); }
