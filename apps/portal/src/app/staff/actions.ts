"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";

import {
  readCreateCatalogueItemForm,
  readSetCatalogueStatusForm,
  readUpdateCatalogueItemForm,
} from "@/lib/staff-catalogue-form";
import { getStaffOAuthCallbackUrl } from "@/lib/staff-oauth";
import { createServerSupabaseClient } from "@/lib/supabase-server";

function destination(path: string, key: "error" | "notice", value: string) {
  const query = new URLSearchParams({ [key]: value });
  return `${path}?${query.toString()}`;
}

function mutationErrorPath(
  path: string,
  error: { code?: string; message: string },
): string {
  console.error(`[staff-catalogue:mutation] ${error.code ?? "unknown"}`);

  if (
    error.code === "40001" ||
    error.message.includes("catalogue_version_conflict")
  ) {
    return destination(path, "error", "conflict");
  }
  if (error.code === "23505") {
    return destination(path, "error", "duplicate");
  }
  if (
    error.code === "42501" ||
    error.code === "28000" ||
    error.message.includes("staff_permission_denied")
  ) {
    return destination(path, "error", "access_denied");
  }
  if (error.code === "P0002") {
    return destination(path, "error", "not_found");
  }
  if (error.code === "22023") {
    return destination(path, "error", "invalid_input");
  }
  return destination(path, "error", "save_failed");
}

async function verifiedClient() {
  const client = await createServerSupabaseClient();
  const { data, error } = await client.auth.getClaims();
  if (error || typeof data?.claims?.sub !== "string") {
    return null;
  }
  return client;
}

export async function signInWithDiscordAction() {
  const client = await createServerSupabaseClient();
  const { data, error } = await client.auth.signInWithOAuth({
    provider: "discord",
    options: {
      redirectTo: getStaffOAuthCallbackUrl(),
    },
  });
  if (error || !data.url) {
    console.error(`[staff-auth:discord] ${error?.code ?? "missing_url"}`);
    redirect(destination("/staff/login", "error", "provider_unavailable"));
  }
  redirect(data.url);
}

export async function signOutAction() {
  const client = await createServerSupabaseClient();
  await client.auth.signOut();
  redirect("/staff/login");
}

export async function createCatalogueItemAction(formData: FormData) {
  const parsed = readCreateCatalogueItemForm(formData);
  if (!parsed.success) {
    redirect(destination("/staff/items/new", "error", "invalid_input"));
  }

  const client = await verifiedClient();
  if (!client) {
    redirect("/staff/login");
  }
  const input = parsed.data;
  const { data, error } = await client.rpc("staff_create_catalogue_item", {
    p_item_code: input.itemCode,
    p_slug: input.slug,
    p_display_name: input.displayName,
    p_description: input.description,
    p_category_code: input.categoryCode,
    p_unit_code: input.unitCode,
    p_inventory_mode: input.inventoryMode,
    p_internal_notes: input.internalNotes,
    p_reason: input.reason,
    p_request_id: crypto.randomUUID(),
  });
  if (error) {
    redirect(mutationErrorPath("/staff/items/new", error));
  }

  const itemId = Array.isArray(data) ? data[0]?.id : null;
  revalidatePath("/staff");
  if (typeof itemId === "string") {
    redirect(destination(`/staff/items/${itemId}/edit`, "notice", "created"));
  }
  redirect(destination("/staff", "notice", "created"));
}

export async function updateCatalogueItemAction(formData: FormData) {
  const parsed = readUpdateCatalogueItemForm(formData);
  const fallbackId = formData.get("item_id");
  const fallbackPath =
    typeof fallbackId === "string" && z.guid().safeParse(fallbackId).success
      ? `/staff/items/${fallbackId}/edit`
      : "/staff";
  if (!parsed.success) {
    redirect(destination(fallbackPath, "error", "invalid_input"));
  }

  const client = await verifiedClient();
  if (!client) {
    redirect("/staff/login");
  }
  const input = parsed.data;
  const { error } = await client.rpc("staff_update_catalogue_item", {
    p_item_id: input.itemId,
    p_expected_version: input.expectedVersion,
    p_display_name: input.displayName,
    p_description: input.description,
    p_category_code: input.categoryCode,
    p_unit_code: input.unitCode,
    p_inventory_mode: input.inventoryMode,
    p_internal_notes: input.internalNotes,
    p_reason: input.reason,
    p_request_id: crypto.randomUUID(),
  });
  if (error) {
    redirect(mutationErrorPath(fallbackPath, error));
  }

  revalidatePath("/staff");
  revalidatePath(fallbackPath);
  redirect(destination(fallbackPath, "notice", "saved"));
}

export async function setCatalogueItemStatusAction(formData: FormData) {
  const parsed = readSetCatalogueStatusForm(formData);
  const fallbackId = formData.get("item_id");
  const fallbackPath =
    typeof fallbackId === "string" && z.guid().safeParse(fallbackId).success
      ? `/staff/items/${fallbackId}/edit`
      : "/staff";
  if (!parsed.success) {
    redirect(destination(fallbackPath, "error", "invalid_input"));
  }

  const client = await verifiedClient();
  if (!client) {
    redirect("/staff/login");
  }
  const input = parsed.data;
  const { error } = await client.rpc("staff_set_catalogue_item_status", {
    p_item_id: input.itemId,
    p_expected_version: input.expectedVersion,
    p_status: input.status,
    p_reason: input.reason,
    p_request_id: crypto.randomUUID(),
  });
  if (error) {
    redirect(mutationErrorPath(fallbackPath, error));
  }

  revalidatePath("/");
  revalidatePath("/staff");
  revalidatePath(fallbackPath);
  redirect(destination(fallbackPath, "notice", input.status));
}
