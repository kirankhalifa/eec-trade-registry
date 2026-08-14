"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import {
  readAssetLifecycleForm,
  readInspectAssetForm,
  readRegisterAssetForm,
  readReleaseAssetReservationForm,
  readReserveAssetForm,
  readTransferAssetForm,
} from "@/lib/asset-form";
import { createServerSupabaseClient } from "@/lib/supabase-server";

const assetPath = "/staff/assets";
function returnPath(formData: FormData) {
  const candidate = formData.get("return_to");
  return typeof candidate === "string" && /^\/staff\/assets\/[A-Z0-9-]+$/.test(candidate)
    ? candidate
    : assetPath;
}
function destination(key: "error" | "notice", value: string, path = assetPath) {
  return `${path}?${new URLSearchParams({ [key]: value }).toString()}`;
}
function errorPath(error: { code?: string; message: string }, path = assetPath) {
  console.error(`[staff-assets:mutation] ${error.code ?? "unknown"}`);
  if (error.code === "40001" || error.message.includes("version_conflict")) return destination("error", "conflict", path);
  if (error.code === "42501" || error.message.includes("permission_denied")) return destination("error", "access_denied", path);
  if (error.code === "23505") return destination("error", "duplicate", path);
  if (error.code === "P0002") return destination("error", "not_found", path);
  if (error.code === "22023" || error.code === "23514") return destination("error", "invalid_input", path);
  return destination("error", "save_failed", path);
}
async function verifiedClient() {
  const client = await createServerSupabaseClient();
  const { data, error } = await client.auth.getClaims();
  return !error && typeof data?.claims?.sub === "string" ? client : null;
}
function refresh() {
  revalidatePath(assetPath); revalidatePath("/staff"); revalidatePath("/staff/orders");
}

export async function registerAssetAction(formData: FormData) {
  const parsed = readRegisterAssetForm(formData);
  if (!parsed.success) redirect(destination("error", "invalid_input"));
  const client = await verifiedClient(); if (!client) redirect("/staff/login");
  const input = parsed.data;
  const { error } = await client.rpc("staff_register_serialized_asset", {
    p_condition_code: input.conditionCode, p_item_id: input.itemId,
    p_provenance_summary: input.provenanceSummary, p_reason: input.reason,
    p_request_id: crypto.randomUUID(), p_serial_marking: input.serialMarking || null,
    p_stock_location_id: input.stockLocationId,
  });
  if (error) redirect(errorPath(error)); refresh(); redirect(destination("notice", "registered"));
}

export async function reserveAssetAction(formData: FormData) {
  const path = returnPath(formData);
  const parsed = readReserveAssetForm(formData);
  if (!parsed.success) redirect(destination("error", "invalid_input", path));
  const client = await verifiedClient(); if (!client) redirect("/staff/login");
  const input = parsed.data;
  const { error } = await client.rpc("staff_reserve_serialized_asset", {
    p_asset_id: input.assetId, p_expected_version: input.expectedVersion,
    p_order_line_id: input.orderLineId, p_reason: input.reason,
    p_request_id: crypto.randomUUID(),
  });
  if (error) redirect(errorPath(error, path)); refresh(); redirect(destination("notice", "reserved", path));
}

export async function releaseAssetReservationAction(formData: FormData) {
  const path = returnPath(formData);
  const parsed = readReleaseAssetReservationForm(formData);
  if (!parsed.success) redirect(destination("error", "invalid_input", path));
  const client = await verifiedClient(); if (!client) redirect("/staff/login");
  const input = parsed.data;
  const { error } = await client.rpc("staff_release_asset_reservation", {
    p_asset_reservation_id: input.assetReservationId,
    p_expected_version: input.expectedVersion, p_reason: input.reason,
    p_request_id: crypto.randomUUID(),
  });
  if (error) redirect(errorPath(error, path)); refresh(); redirect(destination("notice", "released", path));
}

export async function transferAssetAction(formData: FormData) {
  const path = returnPath(formData);
  const parsed = readTransferAssetForm(formData);
  if (!parsed.success) redirect(destination("error", "invalid_input", path));
  const client = await verifiedClient(); if (!client) redirect("/staff/login");
  const input = parsed.data;
  const [kind, targetId, locationCustodianId] = input.destination.split(":") as ["location" | "party", string, string?];
  const custodian = kind === "location" ? locationCustodianId : targetId;
  if (!custodian) redirect(destination("error", "invalid_input", path));
  const { error } = await client.rpc("staff_transfer_serialized_asset_custody", {
    p_asset_id: input.assetId, p_condition_code: input.conditionCode,
    p_expected_version: input.expectedVersion, p_reason: input.reason,
    p_request_id: crypto.randomUUID(), p_to_custodian_party_id: custodian,
    p_to_stock_location_id: kind === "location" ? targetId : null,
  });
  if (error) redirect(errorPath(error, path)); refresh(); redirect(destination("notice", "custody", path));
}

export async function inspectAssetAction(formData: FormData) {
  const path = returnPath(formData);
  const parsed = readInspectAssetForm(formData);
  if (!parsed.success) redirect(destination("error", "invalid_input", path));
  const client = await verifiedClient(); if (!client) redirect("/staff/login");
  const input = parsed.data;
  const { error } = await client.rpc("staff_record_asset_inspection", {
    p_asset_id: input.assetId, p_condition_code: input.conditionCode,
    p_expected_version: input.expectedVersion,
    p_next_due_at: input.nextDueDate ? `${input.nextDueDate}T12:00:00.000Z` : null,
    p_observation: input.observation, p_reason: input.reason,
    p_request_id: crypto.randomUUID(),
  });
  if (error) redirect(errorPath(error, path)); refresh(); redirect(destination("notice", "inspected", path));
}

export async function changeAssetStatusAction(formData: FormData) {
  const path = returnPath(formData);
  const parsed = readAssetLifecycleForm(formData);
  if (!parsed.success) redirect(destination("error", "invalid_input", path));
  const client = await verifiedClient(); if (!client) redirect("/staff/login");
  const input = parsed.data;
  const { error } = await client.rpc("staff_change_serialized_asset_status", {
    p_asset_id: input.assetId, p_expected_version: input.expectedVersion,
    p_reason: input.reason, p_request_id: crypto.randomUUID(), p_status: input.status,
  });
  if (error) redirect(errorPath(error, path)); refresh(); redirect(destination("notice", "status", path));
}
