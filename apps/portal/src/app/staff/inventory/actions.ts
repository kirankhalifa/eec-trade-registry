"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import {
  readCreateReservationForm,
  readExtendReservationForm,
  readInventoryReceiptForm,
  readReservationMutationForm,
  readReverseInventoryForm,
} from "@/lib/inventory-form";
import { createServerSupabaseClient } from "@/lib/supabase-server";

const inventoryPath = "/staff/inventory";

function destination(key: "error" | "notice", value: string) {
  return `${inventoryPath}?${new URLSearchParams({ [key]: value }).toString()}`;
}

function errorPath(error: { code?: string; message: string }) {
  console.error(`[staff-inventory:mutation] ${error.code ?? "unknown"}`);
  if (error.code === "40001" || error.message.includes("version_conflict")) {
    return destination("error", "conflict");
  }
  if (
    error.code === "42501" ||
    error.code === "28000" ||
    error.message.includes("permission_denied")
  ) {
    return destination("error", "access_denied");
  }
  if (
    error.message.includes("available_insufficient") ||
    error.message.includes("overdrawn") ||
    error.message.includes("reserved_stock")
  ) {
    return destination("error", "insufficient_stock");
  }
  if (error.code === "P0002") return destination("error", "not_found");
  if (error.code === "22023" || error.code === "23514") {
    return destination("error", "invalid_input");
  }
  return destination("error", "save_failed");
}

async function verifiedClient() {
  const client = await createServerSupabaseClient();
  const { data, error } = await client.auth.getClaims();
  return !error && typeof data?.claims?.sub === "string" ? client : null;
}

function refreshInventorySurfaces() {
  revalidatePath(inventoryPath);
  revalidatePath("/staff/orders");
  revalidatePath("/dealer/orders");
}

export async function postInventoryReceiptAction(formData: FormData) {
  const parsed = readInventoryReceiptForm(formData);
  if (!parsed.success) redirect(destination("error", "invalid_input"));
  const client = await verifiedClient();
  if (!client) redirect("/staff/login");
  const input = parsed.data;
  const { error } = await client.rpc("staff_post_inventory_receipt", {
    p_item_id: input.itemId,
    p_quantity: input.quantity,
    p_reason: input.reason,
    p_request_id: crypto.randomUUID(),
    p_source_reference: input.sourceReference,
    p_stock_location_id: input.stockLocationId,
  });
  if (error) redirect(errorPath(error));
  refreshInventorySurfaces();
  redirect(destination("notice", "receipt_posted"));
}

export async function createReservationAction(formData: FormData) {
  const parsed = readCreateReservationForm(formData);
  if (!parsed.success) redirect(destination("error", "invalid_input"));
  const client = await verifiedClient();
  if (!client) redirect("/staff/login");
  const input = parsed.data;
  const { error } = await client.rpc("staff_create_reservation", {
    p_inventory_account_id: input.inventoryAccountId,
    p_order_line_id: input.orderLineId,
    p_quantity: input.quantity,
    p_reason: input.reason,
    p_request_id: crypto.randomUUID(),
  });
  if (error) redirect(errorPath(error));
  refreshInventorySurfaces();
  redirect(destination("notice", "reservation_created"));
}

export async function extendReservationAction(formData: FormData) {
  const parsed = readExtendReservationForm(formData);
  if (!parsed.success) redirect(destination("error", "invalid_input"));
  const client = await verifiedClient();
  if (!client) redirect("/staff/login");
  const input = parsed.data;
  const { error } = await client.rpc("staff_extend_reservation", {
    p_expected_version: input.expectedVersion,
    p_expires_at: input.expiresAt,
    p_reason: input.reason,
    p_request_id: crypto.randomUUID(),
    p_reservation_id: input.reservationId,
  });
  if (error) redirect(errorPath(error));
  refreshInventorySurfaces();
  redirect(destination("notice", "extended"));
}

async function terminateReservation(formData: FormData, target: "released" | "expired") {
  const parsed = readReservationMutationForm(formData);
  if (!parsed.success) redirect(destination("error", "invalid_input"));
  const client = await verifiedClient();
  if (!client) redirect("/staff/login");
  const input = parsed.data;
  const functionName = target === "released"
    ? "staff_release_reservation"
    : "staff_expire_reservation";
  const { error } = await client.rpc(functionName, {
    p_expected_version: input.expectedVersion,
    p_reason: input.reason,
    p_request_id: crypto.randomUUID(),
    p_reservation_id: input.reservationId,
  });
  if (error) redirect(errorPath(error));
  refreshInventorySurfaces();
  redirect(destination("notice", target));
}

export async function releaseReservationAction(formData: FormData) {
  return terminateReservation(formData, "released");
}

export async function expireReservationAction(formData: FormData) {
  return terminateReservation(formData, "expired");
}

export async function reverseInventoryTransactionAction(formData: FormData) {
  const parsed = readReverseInventoryForm(formData);
  if (!parsed.success) redirect(destination("error", "invalid_input"));
  const client = await verifiedClient();
  if (!client) redirect("/staff/login");
  const input = parsed.data;
  const { error } = await client.rpc("staff_reverse_inventory_transaction", {
    p_inventory_transaction_id: input.inventoryTransactionId,
    p_reason: input.reason,
    p_request_id: crypto.randomUUID(),
  });
  if (error) redirect(errorPath(error));
  refreshInventorySurfaces();
  redirect(destination("notice", "reversed"));
}
