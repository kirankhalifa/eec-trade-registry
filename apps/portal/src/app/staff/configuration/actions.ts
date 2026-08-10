"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import {
  readConfigurationReferenceForm,
  readControlProfileForm,
  readPublicTermsForm,
  readQuickItemForm,
  readQuickReceiptForm,
} from "@/lib/configuration-form";
import { createServerSupabaseClient } from "@/lib/supabase-server";

const configurationPath = "/staff/configuration";

function destination(key: "error" | "notice", value: string) {
  return `${configurationPath}?${new URLSearchParams({ [key]: value })}`;
}

function mutationErrorPath(error: { code?: string; message: string }) {
  console.error(`[staff-configuration:mutation] ${error.code ?? "unknown"}`);
  if (error.code === "42501" || error.code === "28000") return destination("error", "access_denied");
  if (error.code === "23505") return destination("error", "duplicate");
  if (error.code === "P0002") return destination("error", "not_found");
  if (error.code === "40001" || error.message.includes("version_conflict")) return destination("error", "conflict");
  if (["22023", "23514", "23P01"].includes(error.code ?? "")) return destination("error", "invalid_input");
  return destination("error", "save_failed");
}

async function verifiedClient() {
  const client = await createServerSupabaseClient();
  const { data, error } = await client.auth.getClaims();
  return !error && typeof data?.claims?.sub === "string" ? client : null;
}

function refreshConfiguration() {
  revalidatePath(configurationPath);
  revalidatePath("/staff");
  revalidatePath("/staff/economy");
  revalidatePath("/staff/inventory");
  revalidatePath("/catalogue");
  revalidatePath("/");
}

export async function quickCreateItemAction(formData: FormData) {
  const parsed = readQuickItemForm(formData);
  if (!parsed.success) redirect(destination("error", "invalid_input"));
  const client = await verifiedClient();
  if (!client) redirect("/staff/login");
  const input = parsed.data;
  const reason = input.reason || `Quick-create ${input.displayName} with configured trade terms.`;
  const { error } = await client.rpc("staff_quick_create_item", {
    p_availability_profile_code: input.availabilityProfileCode,
    p_business_bulk_review_threshold: input.businessBulkReviewThreshold,
    p_category_code: input.categoryCode,
    p_control_profile_code: input.controlProfileCode,
    p_critical_level: input.criticalLevel,
    p_description: input.description,
    p_direct_individual_allowed: input.directIndividualAllowed,
    p_direct_weekly_limit: input.directWeeklyLimit,
    p_display_name: input.displayName,
    p_item_code: input.itemCode,
    p_minimum_level: input.minimumLevel,
    p_opening_quantity: input.openingQuantity,
    p_opening_stock_location_id: input.openingStockLocationId,
    p_price_amount_minor: input.priceAmountMinor,
    p_price_schedule_id: input.priceScheduleId,
    p_publish: input.publish,
    p_reason: reason,
    p_request_id: crypto.randomUUID(),
    p_requirement_summary: input.requirementSummary,
    p_slug: input.slug,
    p_source_reference: input.sourceReference,
    p_supply_mode: input.supplyMode,
    p_surplus_level: input.surplusLevel,
    p_target_level: input.targetLevel,
    p_unit_code: input.unitCode,
  });
  if (error) redirect(mutationErrorPath(error));
  refreshConfiguration();
  redirect(destination("notice", "item_created"));
}

export async function quickReceiptAction(formData: FormData) {
  const parsed = readQuickReceiptForm(formData);
  if (!parsed.success) redirect(destination("error", "invalid_input"));
  const client = await verifiedClient();
  if (!client) redirect("/staff/login");
  const input = parsed.data;
  const { error } = await client.rpc("staff_quick_post_inventory_receipt", {
    p_item_code: input.itemCode,
    p_quantity: input.quantity,
    p_reason: input.reason,
    p_request_id: crypto.randomUUID(),
    p_source_reference: input.sourceReference,
    p_stock_location_id: input.stockLocationId,
  });
  if (error) redirect(mutationErrorPath(error));
  refreshConfiguration();
  redirect(destination("notice", "receipt_posted"));
}

export async function createConfigurationReferenceAction(formData: FormData) {
  const parsed = readConfigurationReferenceForm(formData);
  if (!parsed.success) redirect(destination("error", "invalid_input"));
  const client = await verifiedClient();
  if (!client) redirect("/staff/login");
  const input = parsed.data;
  const reason = input.reason || `Create configured ${input.kind.replaceAll("_", " ")} ${input.displayName}.`;
  const { error } = await client.rpc("staff_create_configuration_reference", {
    p_code: input.code,
    p_description: input.description,
    p_display_name: input.displayName,
    p_kind: input.kind,
    p_public_display_name: input.publicDisplayName,
    p_quantity_scale: input.quantityScale,
    p_reason: reason,
    p_request_id: crypto.randomUUID(),
    p_sort_order: input.sortOrder,
    p_symbol: input.symbol,
  });
  if (error) redirect(mutationErrorPath(error));
  refreshConfiguration();
  redirect(destination("notice", "reference_created"));
}

export async function createControlProfileAction(formData: FormData) {
  const parsed = readControlProfileForm(formData);
  if (!parsed.success) redirect(destination("error", "invalid_input"));
  const client = await verifiedClient();
  if (!client) redirect("/staff/login");
  const input = parsed.data;
  const reason = input.reason || `Create configured control profile ${input.displayName}.`;
  const { error } = await client.rpc("staff_create_control_profile", {
    p_code: input.code,
    p_display_name: input.displayName,
    p_public_description: input.publicDescription,
    p_reason: reason,
    p_request_id: crypto.randomUUID(),
    p_requires_serial_tracking: input.requiresSerialTracking,
    p_requires_staff_review: input.requiresStaffReview,
    p_requires_transaction_approval: input.requiresTransactionApproval,
  });
  if (error) redirect(mutationErrorPath(error));
  refreshConfiguration();
  redirect(destination("notice", "control_created"));
}

export async function setItemPublicTermsAction(formData: FormData) {
  const parsed = readPublicTermsForm(formData);
  if (!parsed.success) redirect(destination("error", "invalid_input"));
  const client = await verifiedClient();
  if (!client) redirect("/staff/login");
  const input = parsed.data;
  const reason = input.reason || `Update public catalogue terms for ${input.publicName}.`;
  const { error } = await client.rpc("staff_set_item_public_terms", {
    p_availability_profile_code: input.availabilityProfileCode,
    p_bulk_minimum: input.bulkMinimum,
    p_control_profile_code: input.controlProfileCode,
    p_item_id: input.itemId,
    p_order_increment: input.orderIncrement,
    p_price_action: input.priceAction,
    p_price_amount_minor: input.priceAmountMinor,
    p_price_schedule_id: input.priceScheduleId,
    p_public_description: input.publicDescription,
    p_public_name: input.publicName,
    p_publish: input.publish,
    p_reason: reason,
    p_request_id: crypto.randomUUID(),
    p_requirement_summary: input.requirementSummary,
  });
  if (error) redirect(mutationErrorPath(error));
  refreshConfiguration();
  redirect(destination("notice", "terms_saved"));
}
