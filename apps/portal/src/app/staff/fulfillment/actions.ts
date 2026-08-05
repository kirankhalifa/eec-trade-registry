"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import {
  readFulfillReservationForm,
  readReverseFulfillmentForm,
} from "@/lib/fulfillment-form";
import { createServerSupabaseClient } from "@/lib/supabase-server";

const fulfillmentPath = "/staff/fulfillment";

function destination(key: "error" | "notice", value: string) {
  return `${fulfillmentPath}?${new URLSearchParams({ [key]: value }).toString()}`;
}

function errorPath(error: { code?: string; message: string }) {
  console.error(`[staff-fulfillment:mutation] ${error.code ?? "unknown"}`);
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
    error.message.includes("stock_insufficient") ||
    error.message.includes("negative_stock") ||
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

function refreshFulfillmentSurfaces() {
  revalidatePath(fulfillmentPath);
  revalidatePath("/staff/inventory");
  revalidatePath("/staff/orders");
  revalidatePath("/dealer/orders");
}

export async function fulfillReservationAction(formData: FormData) {
  const parsed = readFulfillReservationForm(formData);
  if (!parsed.success) redirect(destination("error", "invalid_input"));
  const client = await verifiedClient();
  if (!client) redirect("/staff/login");
  const input = parsed.data;
  const { error } = await client.rpc("staff_fulfill_reservation", {
    p_expected_version: input.expectedVersion,
    p_reason: input.reason,
    p_request_id: crypto.randomUUID(),
    p_reservation_id: input.reservationId,
  });
  if (error) redirect(errorPath(error));
  refreshFulfillmentSurfaces();
  redirect(destination("notice", "completed"));
}

export async function reverseFulfillmentAction(formData: FormData) {
  const parsed = readReverseFulfillmentForm(formData);
  if (!parsed.success) redirect(destination("error", "invalid_input"));
  const client = await verifiedClient();
  if (!client) redirect("/staff/login");
  const input = parsed.data;
  const { error } = await client.rpc("staff_reverse_fulfillment", {
    p_expected_version: input.expectedVersion,
    p_fulfillment_id: input.fulfillmentId,
    p_reason: input.reason,
    p_request_id: crypto.randomUUID(),
  });
  if (error) redirect(errorPath(error));
  refreshFulfillmentSurfaces();
  redirect(destination("notice", "reversed"));
}
