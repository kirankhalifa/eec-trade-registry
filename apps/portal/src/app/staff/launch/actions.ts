"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import {
  decisionSchema, documentGenerationSchema, financeTermSchema, fulfillmentSchema,
  parse, paymentSchema, priceBindingSchema, readAssistedOrderForm, settlementSchema,
} from "@/lib/launch-form";
import { createServerSupabaseClient } from "@/lib/supabase-server";

const base = "/staff/launch";
function destination(key: "error" | "notice", value: string) { return `${base}?${new URLSearchParams({ [key]: value })}`; }
async function client() {
  const instance = await createServerSupabaseClient(); const { data, error } = await instance.auth.getClaims();
  if (error || typeof data?.claims?.sub !== "string") redirect("/staff/login"); return instance;
}
function failure(error: { code?: string; message: string }) {
  console.error(`[launch-command] ${error.code ?? "unknown"}: ${error.message}`);
  if (error.code === "40001" || error.message.includes("version_conflict")) return "conflict";
  if (error.message.includes("weekly_limit")) return "weekly_limit";
  if (error.message.includes("price_unavailable")) return "price_missing";
  if (error.code === "42501" || error.message.includes("permission_denied")) return "access_denied";
  if (error.code === "P0002") return "not_found";
  return "save_failed";
}
function refresh() { revalidatePath(base); revalidatePath("/staff/dashboard"); revalidatePath("/staff/orders"); }

export async function createTradeOrderAction(form: FormData) {
  const parsed = readAssistedOrderForm(form); if (!parsed.success) redirect(destination("error", "invalid_input"));
  const input = parsed.data; let party: string | null = input.direct_customer_id;
  let dealer: string | null = null; let license: string | null = null; let jurisdiction = input.jurisdiction_id;
  if (input.channel === "staff_assisted_business") {
    const parts = input.business_key.split("|"); if (parts.length !== 4) redirect(destination("error", "invalid_input"));
    [party, dealer, license, jurisdiction] = parts;
  }
  const { error } = await (await client()).rpc("staff_create_trade_order", {
    p_channel: input.channel, p_contact_label: input.contact_label, p_customer_name: input.new_customer_name,
    p_customer_party_id: party, p_dealer_authorization_id: dealer, p_fulfillment_mode: input.fulfillment_mode,
    p_jurisdiction_id: jurisdiction, p_license_id: license, p_lines: input.lines, p_notes: input.notes,
    p_reason: input.reason, p_request_id: crypto.randomUUID(),
  });
  if (error) redirect(destination("error", failure(error))); refresh(); redirect(destination("notice", "order_created"));
}

export async function decideApplicationAction(form: FormData) {
  const parsed = parse(decisionSchema, form); if (!parsed.success) redirect(destination("error", "invalid_input"));
  const input = parsed.data; const { error } = await (await client()).rpc("staff_decide_license_application", {
    p_application_id: input.application_id, p_decision: input.decision, p_effective_from: input.effective_from,
    p_expected_version: input.expected_version, p_expires_at: input.expires_at, p_holder_party_id: input.holder_party_id,
    p_initial_status_code: input.initial_status_code, p_reason: input.reason, p_request_id: crypto.randomUUID(),
  });
  if (error) redirect(destination("error", failure(error))); refresh(); revalidatePath("/staff/licensing"); redirect(destination("notice", "application_decided"));
}

export async function configureFinanceTermsAction(form: FormData) {
  const parsed = parse(financeTermSchema, form); if (!parsed.success) redirect(destination("error", "invalid_input")); const input = parsed.data;
  const { error } = await (await client()).rpc("staff_configure_consignment_finance_terms", {
    p_agreement_id: input.agreement_id, p_commission_basis_points: Math.round(input.commission_percent * 100),
    p_currency_code: input.currency_code.toUpperCase(), p_effective_from: input.effective_from,
    p_effective_until: input.effective_until, p_reason: input.reason, p_request_id: crypto.randomUUID(),
  });
  if (error) redirect(destination("error", failure(error))); refresh(); redirect(destination("notice", "terms_configured"));
}

export async function createSettlementAction(form: FormData) {
  const parsed = parse(settlementSchema, form); if (!parsed.success) redirect(destination("error", "invalid_input")); const input = parsed.data;
  const { error } = await (await client()).rpc("staff_create_consignment_settlement", {
    p_consignment_report_id: input.report_id, p_reason: input.reason, p_request_id: crypto.randomUUID(), p_unit_sale_price_minor: input.unit_sale_price,
  });
  if (error) redirect(destination("error", failure(error))); refresh(); redirect(destination("notice", "settlement_created"));
}

export async function markSettlementPaidAction(form: FormData) {
  const parsed = parse(paymentSchema, form); if (!parsed.success) redirect(destination("error", "invalid_input")); const input = parsed.data;
  const { error } = await (await client()).rpc("staff_mark_consignment_settlement_paid", {
    p_expected_version: input.expected_version, p_payment_reference: input.payment_reference, p_reason: input.reason,
    p_request_id: crypto.randomUUID(), p_settlement_id: input.settlement_id,
  });
  if (error) redirect(destination("error", failure(error))); refresh(); redirect(destination("notice", "settlement_paid"));
}

export async function fulfillUniqueAssetAction(form: FormData) {
  const parsed = parse(fulfillmentSchema, form); if (!parsed.success) redirect(destination("error", "invalid_input")); const input = parsed.data;
  const { error } = await (await client()).rpc("staff_fulfill_unique_asset", {
    p_asset_reservation_id: input.reservation_id, p_expected_asset_version: input.asset_version,
    p_expected_reservation_version: input.reservation_version, p_reason: input.reason, p_request_id: crypto.randomUUID(),
  });
  if (error) redirect(destination("error", failure(error))); refresh(); revalidatePath("/staff/assets"); redirect(destination("notice", "asset_fulfilled"));
}

export async function generateDocumentAction(form: FormData) {
  const parsed = parse(documentGenerationSchema, form); if (!parsed.success) redirect(destination("error", "invalid_input")); const input = parsed.data;
  const { error } = await (await client()).rpc("staff_generate_document_snapshot", {
    p_document_type: input.document_type, p_reason: input.reason, p_request_id: crypto.randomUUID(), p_source_record_id: input.source_record_id,
  });
  if (error) redirect(destination("error", failure(error))); revalidatePath("/staff/documents"); refresh(); redirect("/staff/documents?notice=generated");
}

export async function configurePriceBindingAction(form: FormData) {
  const parsed = parse(priceBindingSchema, form); if (!parsed.success) redirect(destination("error", "invalid_input")); const input = parsed.data;
  const { error } = await (await client()).rpc("staff_configure_price_binding", {
    p_binding_type: input.binding_type, p_channel_code: input.channel_code ?? null, p_effective_from: input.effective_from,
    p_effective_until: input.effective_until, p_priority: input.priority, p_reason: input.reason,
    p_request_id: crypto.randomUUID(), p_schedule_id: input.schedule_id, p_target_id: input.target_id,
  });
  if (error) redirect(destination("error", failure(error))); refresh(); redirect(destination("notice", "price_binding_created"));
}
