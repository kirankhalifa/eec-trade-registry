"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { readCreateTransferForm, readTransferCommandForm } from "@/lib/transfer-form";
import { createServerSupabaseClient } from "@/lib/supabase-server";

const transferPath = "/staff/transfers";

function destination(key: "error" | "notice", value: string) {
  return `${transferPath}?${new URLSearchParams({ [key]: value }).toString()}`;
}

function errorPath(error: { code?: string; message: string }) {
  console.error(`[staff-transfers:mutation] ${error.code ?? "unknown"}`);
  if (error.code === "40001" || error.message.includes("version_conflict")) {
    return destination("error", "conflict");
  }
  if (error.code === "42501" || error.message.includes("permission_denied")) {
    return destination("error", "access_denied");
  }
  if (error.message.includes("stock_unavailable") || error.message.includes("negative")) {
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

function refreshTransferSurfaces() {
  revalidatePath(transferPath);
  revalidatePath("/staff/inventory");
  revalidatePath("/staff");
}

export async function createTransferAction(formData: FormData) {
  const parsed = readCreateTransferForm(formData);
  if (!parsed.success) redirect(destination("error", "invalid_input"));
  const client = await verifiedClient();
  if (!client) redirect("/staff/login");
  const input = parsed.data;
  const { error } = await client.rpc("staff_create_stock_transfer", {
    p_destination_inventory_account_id: input.destinationInventoryAccountId,
    p_quantity: input.quantity,
    p_reason: input.reason,
    p_request_id: crypto.randomUUID(),
    p_source_inventory_account_id: input.sourceInventoryAccountId,
  });
  if (error) redirect(errorPath(error));
  refreshTransferSurfaces();
  redirect(destination("notice", "created"));
}

async function runTransferCommand(
  formData: FormData,
  rpc:
    | "staff_authorize_stock_transfer"
    | "staff_cancel_stock_transfer"
    | "staff_dispatch_stock_transfer"
    | "staff_dispute_stock_transfer"
    | "staff_receive_stock_transfer",
  notice: string,
) {
  const parsed = readTransferCommandForm(formData);
  if (!parsed.success) redirect(destination("error", "invalid_input"));
  const client = await verifiedClient();
  if (!client) redirect("/staff/login");
  const input = parsed.data;
  const { error } = await client.rpc(rpc, {
    p_expected_version: input.expectedVersion,
    p_reason: input.reason,
    p_request_id: crypto.randomUUID(),
    p_stock_transfer_id: input.stockTransferId,
  });
  if (error) redirect(errorPath(error));
  refreshTransferSurfaces();
  redirect(destination("notice", notice));
}

export async function authorizeTransferAction(formData: FormData) {
  return runTransferCommand(formData, "staff_authorize_stock_transfer", "authorized");
}

export async function cancelTransferAction(formData: FormData) {
  return runTransferCommand(formData, "staff_cancel_stock_transfer", "cancelled");
}

export async function dispatchTransferAction(formData: FormData) {
  return runTransferCommand(formData, "staff_dispatch_stock_transfer", "dispatched");
}

export async function disputeTransferAction(formData: FormData) {
  return runTransferCommand(formData, "staff_dispute_stock_transfer", "disputed");
}

export async function receiveTransferAction(formData: FormData) {
  return runTransferCommand(formData, "staff_receive_stock_transfer", "received");
}
