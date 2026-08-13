"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";

import {
  readCancelOrderForm,
  readPriceOrderLineForm,
  readReviewOrderLineForm,
} from "@/lib/order-form";
import { readCreateReservationForm } from "@/lib/inventory-form";
import { readFulfillReservationForm } from "@/lib/fulfillment-form";
import { createServerSupabaseClient } from "@/lib/supabase-server";

function destination(path: string, key: "error" | "notice", value: string) {
  return `${path}?${new URLSearchParams({ [key]: value }).toString()}`;
}

function orderPath(value: FormDataEntryValue | null) {
  return typeof value === "string" && z.guid().safeParse(value).success
    ? `/staff/orders/${value}`
    : "/staff/orders";
}

function errorPath(path: string, error: { code?: string; message: string }) {
  console.error(`[staff-orders:mutation] ${error.code ?? "unknown"}`);
  if (error.code === "40001" || error.message.includes("version_conflict")) {
    return destination(path, "error", "conflict");
  }
  if (
    error.code === "42501" ||
    error.code === "28000" ||
    error.message.includes("permission_denied")
  ) {
    return destination(path, "error", "access_denied");
  }
  if (error.code === "P0002") return destination(path, "error", "not_found");
  if (
    error.message.includes("available_insufficient") ||
    error.message.includes("stock_insufficient") ||
    error.message.includes("negative_stock") ||
    error.message.includes("reserved_stock")
  ) {
    return destination(path, "error", "insufficient_stock");
  }
  if (error.code === "22023") return destination(path, "error", "invalid_input");
  return destination(path, "error", "save_failed");
}

function refreshOrderWorkflow(path: string) {
  revalidatePath("/staff/orders");
  revalidatePath(path);
  revalidatePath("/staff/inventory");
  revalidatePath("/staff/fulfillment");
  revalidatePath("/staff/dashboard");
  revalidatePath("/dealer/orders");
}

async function verifiedClient() {
  const client = await createServerSupabaseClient();
  const { data, error } = await client.auth.getClaims();
  return !error && typeof data?.claims?.sub === "string" ? client : null;
}

export async function reviewOrderLineAction(formData: FormData) {
  const path = orderPath(formData.get("order_id"));
  const parsed = readReviewOrderLineForm(formData);
  if (!parsed.success) redirect(destination(path, "error", "invalid_input"));

  const client = await verifiedClient();
  if (!client) redirect("/staff/login");
  const input = parsed.data;
  const { error } = await client.rpc("staff_review_order_line", {
    p_decision: input.decision,
    p_expected_order_version: input.expectedOrderVersion,
    p_order_line_id: input.orderLineId,
    p_quantity_approved: input.decision === "deny" ? null : input.approvedQuantity,
    p_reason: input.reason,
    p_request_id: crypto.randomUUID(),
    p_unit_price_minor: input.unitPriceMinor,
  });
  if (error) redirect(errorPath(path, error));

  revalidatePath("/staff/orders");
  revalidatePath(path);
  revalidatePath("/dealer/orders");
  redirect(destination(path, "notice", "line_reviewed"));
}

export async function priceOrderLineAction(formData: FormData) {
  const path = orderPath(formData.get("order_id"));
  const parsed = readPriceOrderLineForm(formData);
  if (!parsed.success) redirect(destination(path, "error", "invalid_input"));

  const client = await verifiedClient();
  if (!client) redirect("/staff/login");
  const input = parsed.data;
  const { error } = await client.rpc("staff_set_order_line_price", {
    p_expected_order_version: input.expectedOrderVersion,
    p_order_line_id: input.orderLineId,
    p_reason: input.reason,
    p_request_id: crypto.randomUUID(),
    p_unit_price_minor: input.unitPriceMinor,
  });
  if (error) redirect(errorPath(path, error));

  revalidatePath("/staff/orders");
  revalidatePath(path);
  revalidatePath("/dealer/orders");
  redirect(destination(path, "notice", "line_priced"));
}

export async function cancelStaffOrderAction(formData: FormData) {
  const path = orderPath(formData.get("order_id"));
  const parsed = readCancelOrderForm(formData);
  if (!parsed.success) redirect(destination(path, "error", "invalid_input"));

  const client = await verifiedClient();
  if (!client) redirect("/staff/login");
  const input = parsed.data;
  const { error } = await client.rpc("staff_cancel_order", {
    p_expected_version: input.expectedVersion,
    p_order_id: input.orderId,
    p_reason: input.reason,
    p_request_id: crypto.randomUUID(),
  });
  if (error) redirect(errorPath(path, error));

  revalidatePath("/staff/orders");
  revalidatePath(path);
  revalidatePath("/dealer/orders");
  redirect(destination(path, "notice", "cancelled"));
}

export async function reserveOrderLineAction(formData: FormData) {
  const path = orderPath(formData.get("order_id"));
  const parsed = readCreateReservationForm(formData);
  if (!parsed.success) redirect(destination(path, "error", "invalid_input"));
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
  if (error) redirect(errorPath(path, error));
  refreshOrderWorkflow(path);
  redirect(destination(path, "notice", "reservation_created"));
}

export async function fulfillOrderReservationAction(formData: FormData) {
  const path = orderPath(formData.get("order_id"));
  const parsed = readFulfillReservationForm(formData);
  if (!parsed.success) redirect(destination(path, "error", "invalid_input"));
  const client = await verifiedClient();
  if (!client) redirect("/staff/login");
  const input = parsed.data;
  const { error } = await client.rpc("staff_fulfill_reservation", {
    p_expected_version: input.expectedVersion,
    p_reason: input.reason,
    p_request_id: crypto.randomUUID(),
    p_reservation_id: input.reservationId,
  });
  if (error) redirect(errorPath(path, error));
  refreshOrderWorkflow(path);
  redirect(destination(path, "notice", "fulfilled"));
}
