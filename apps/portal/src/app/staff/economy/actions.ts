"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import {
  readDeliveryForm, readOfferForm, readSettlementForm, readSupplierForm, readSupplyPolicyForm,
} from "@/lib/economy-form";
import { createServerSupabaseClient } from "@/lib/supabase-server";

const economyPath = "/staff/economy";
function returnPath(formData: FormData) {
  const candidate = formData.get("return_to");
  return typeof candidate === "string" && (candidate === "/staff/buy" || /^\/staff\/materials\/[A-Za-z0-9-]+$/.test(candidate))
    ? candidate
    : economyPath;
}
function destination(key: "error" | "notice", value: string, path = economyPath) {
  return `${path}?${new URLSearchParams({ [key]: value })}`;
}
function errorPath(error: { code?: string; message: string }, path = economyPath) {
  console.error(`[staff-economy:mutation] ${error.code ?? "unknown"}`);
  if (error.code === "40001" || error.message.includes("version_conflict")) return destination("error", "conflict", path);
  if (error.code === "42501" || error.code === "28000") return destination("error", "access_denied", path);
  if (error.code === "P0002") return destination("error", "not_found", path);
  if (error.message.includes("player_sourced_procurement_required")) return destination("error", "player_source_required", path);
  if (["22023", "23514", "23P01"].includes(error.code ?? "")) return destination("error", "invalid_input", path);
  return destination("error", "save_failed", path);
}
async function verifiedClient() {
  const client = await createServerSupabaseClient();
  const { data, error } = await client.auth.getClaims();
  return !error && typeof data?.claims?.sub === "string" ? client : null;
}
function refresh() {
  revalidatePath(economyPath); revalidatePath("/staff/inventory");
  revalidatePath("/staff/buy"); revalidatePath("/staff/dashboard");
  revalidatePath("/staff/orders"); revalidatePath("/catalogue");
}

export async function saveSupplyPolicyAction(formData: FormData) {
  const path = returnPath(formData);
  const parsed = readSupplyPolicyForm(formData);
  if (!parsed.success) redirect(destination("error", "invalid_input", path));
  const client = await verifiedClient(); if (!client) redirect("/staff/login");
  const input = parsed.data;
  const { error } = await client.rpc("staff_upsert_item_supply_policy", {
    p_admin_receipt_allowed: input.adminReceiptAllowed,
    p_business_bulk_review_threshold: input.businessBulkReviewThreshold,
    p_critical_level: input.criticalLevel, p_direct_individual_allowed: input.directIndividualAllowed,
    p_direct_weekly_limit: input.directWeeklyLimit, p_expected_version: input.expectedVersion,
    p_item_id: input.itemId, p_minimum_level: input.minimumLevel,
    p_player_sourced_only: input.playerSourcedOnly, p_procurement_enabled: input.procurementEnabled,
    p_reason: input.reason, p_request_id: crypto.randomUUID(), p_supply_mode: input.supplyMode,
    p_surplus_level: input.surplusLevel, p_target_level: input.targetLevel,
  });
  if (error) redirect(errorPath(error, path)); refresh(); redirect(destination("notice", "policy_saved", path));
}

export async function registerSupplierAction(formData: FormData) {
  const path = returnPath(formData);
  const parsed = readSupplierForm(formData);
  if (!parsed.success) redirect(destination("error", "invalid_input", path));
  const client = await verifiedClient(); if (!client) redirect("/staff/login");
  const input = parsed.data;
  const { error } = await client.rpc("staff_register_procurement_supplier", {
    p_display_name: input.displayName, p_jurisdiction_id: input.jurisdictionId,
    p_legal_name: input.legalName, p_notes: input.notes, p_party_type_code: input.partyTypeCode,
    p_reason: input.reason, p_request_id: crypto.randomUUID(),
  });
  if (error) redirect(errorPath(error, path)); refresh(); redirect(destination("notice", "supplier_registered", path));
}

export async function createOfferAction(formData: FormData) {
  const path = returnPath(formData);
  const parsed = readOfferForm(formData);
  if (!parsed.success) redirect(destination("error", "invalid_input", path));
  const client = await verifiedClient(); if (!client) redirect("/staff/login");
  const input = parsed.data;
  const { error } = await client.rpc("staff_create_procurement_offer", {
    p_amount_minor: input.amountMinor, p_currency_id: input.currencyId,
    p_effective_from: input.effectiveFrom, p_effective_until: input.effectiveUntil,
    p_item_id: input.itemId, p_minimum_quantity: input.minimumQuantity,
    p_notes: input.notes, p_reason: input.reason, p_request_id: crypto.randomUUID(),
    p_staff_review_quantity: input.staffReviewQuantity,
  });
  if (error) redirect(errorPath(error, path)); refresh(); redirect(destination("notice", "offer_created", path));
}

export async function recordDeliveryAction(formData: FormData) {
  const path = returnPath(formData);
  const parsed = readDeliveryForm(formData);
  if (!parsed.success) redirect(destination("error", "invalid_input", path));
  const client = await verifiedClient(); if (!client) redirect("/staff/login");
  const input = parsed.data;
  const { error } = await client.rpc("staff_record_procurement_delivery", {
    p_procurement_offer_id: input.offerId, p_quantity: input.quantity,
    p_reason: input.reason, p_request_id: crypto.randomUUID(),
    p_stock_location_id: input.stockLocationId, p_supplier_id: input.supplierId,
  });
  if (error) redirect(errorPath(error, path)); refresh(); redirect(destination("notice", "delivery_received", path));
}

export async function settleDeliveryAction(formData: FormData) {
  const parsed = readSettlementForm(formData);
  if (!parsed.success) redirect(destination("error", "invalid_input"));
  const client = await verifiedClient(); if (!client) redirect("/staff/login");
  const input = parsed.data;
  const { error } = await client.rpc("staff_mark_procurement_delivery_paid", {
    p_delivery_id: input.deliveryId, p_expected_version: input.expectedVersion,
    p_reason: input.reason, p_request_id: crypto.randomUUID(),
    p_settlement_reference: input.settlementReference,
  });
  if (error) redirect(errorPath(error)); refresh(); redirect(destination("notice", "delivery_settled"));
}
