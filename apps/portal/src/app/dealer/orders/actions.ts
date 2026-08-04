"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";

import { readCancelOrderForm, readSubmitOrderForm } from "@/lib/order-form";
import { createServerSupabaseClient } from "@/lib/supabase-server";

function destination(path: string, key: "error" | "notice", value: string) {
  return `${path}?${new URLSearchParams({ [key]: value }).toString()}`;
}

function orderPath(value: FormDataEntryValue | null) {
  return typeof value === "string" && z.string().uuid().safeParse(value).success
    ? `/dealer/orders/${value}`
    : "/dealer/orders";
}

function errorPath(path: string, error: { code?: string; message: string }) {
  console.error(`[dealer-orders:mutation] ${error.code ?? "unknown"}`);
  if (error.code === "40001" || error.message.includes("version_conflict")) {
    return destination(path, "error", "conflict");
  }
  if (
    error.code === "42501" ||
    error.code === "28000" ||
    error.message.includes("scope_denied")
  ) {
    return destination(path, "error", "access_denied");
  }
  if (error.code === "P0002") return destination(path, "error", "not_found");
  if (error.code === "22023") return destination(path, "error", "invalid_input");
  return destination(path, "error", "save_failed");
}

async function verifiedClient() {
  const client = await createServerSupabaseClient();
  const { data, error } = await client.auth.getClaims();
  return !error && typeof data?.claims?.sub === "string" ? client : null;
}

export async function submitDealerOrderAction(formData: FormData) {
  const parsed = readSubmitOrderForm(formData);
  if (!parsed.success) {
    redirect(destination("/dealer/orders/new", "error", "invalid_input"));
  }

  const client = await verifiedClient();
  if (!client) redirect("/dealer/login");
  const input = parsed.data;
  const { data, error } = await client.rpc("dealer_submit_order", {
    p_dealer_authorization_id: input.dealerAuthorizationId,
    p_dealer_notes: input.dealerNotes,
    p_fulfillment_mode: input.fulfillmentMode,
    p_item_ids: input.lines.map((line) => line.itemId),
    p_license_id: input.licenseId,
    p_ordering_party_id: input.orderingPartyId,
    p_quantities: input.lines.map((line) => line.quantity),
    p_reason: input.reason,
    p_request_id: crypto.randomUUID(),
  });
  if (error) redirect(errorPath("/dealer/orders/new", error));

  const orderId = Array.isArray(data) ? data[0]?.id : null;
  revalidatePath("/dealer/orders");
  revalidatePath("/staff/orders");
  if (typeof orderId === "string") {
    redirect(destination(`/dealer/orders/${orderId}`, "notice", "submitted"));
  }
  redirect(destination("/dealer/orders", "notice", "submitted"));
}

export async function cancelDealerOrderAction(formData: FormData) {
  const path = orderPath(formData.get("order_id"));
  const parsed = readCancelOrderForm(formData);
  if (!parsed.success) redirect(destination(path, "error", "invalid_input"));

  const client = await verifiedClient();
  if (!client) redirect("/dealer/login");
  const input = parsed.data;
  const { error } = await client.rpc("dealer_cancel_order", {
    p_expected_version: input.expectedVersion,
    p_order_id: input.orderId,
    p_reason: input.reason,
    p_request_id: crypto.randomUUID(),
  });
  if (error) redirect(errorPath(path, error));

  revalidatePath("/dealer/orders");
  revalidatePath(path);
  revalidatePath("/staff/orders");
  redirect(destination(path, "notice", "cancelled"));
}
