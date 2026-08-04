import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";

const staffCatalogueItemSchema = z.object({
  category_code: z.string(),
  category_name: z.string(),
  currency_code: z.string().nullable(),
  description: z.string(),
  display_name: z.string(),
  id: z.guid(),
  internal_notes: z.string(),
  inventory_mode: z.enum(["fungible", "serialized"]),
  item_code: z.string(),
  price_amount_minor: z.number().int().safe().nullable(),
  public_name: z.string().nullable(),
  publication_status: z.enum(["draft", "published", "withdrawn"]).nullable(),
  slug: z.string(),
  status: z.enum(["active", "archived"]),
  unit_code: z.string(),
  unit_name: z.string(),
  updated_at: z.string(),
  version: z.number().int().positive().safe(),
});

const referenceOptionSchema = z.object({
  code: z.string(),
  display_name: z.string(),
});

const referenceDataSchema = z.object({
  categories: z.array(referenceOptionSchema),
  units: z.array(referenceOptionSchema),
});

export type StaffCatalogueItem = z.infer<typeof staffCatalogueItemSchema>;
export type StaffCatalogueReferenceData = z.infer<typeof referenceDataSchema>;

export type StaffCatalogueResult<T> =
  | { ok: true; data: T }
  | {
      ok: false;
      code: "access_denied" | "invalid_response" | "query_failed";
    };

function errorCode(message: string): "access_denied" | "query_failed" {
  return message.includes("staff_permission_denied") ||
    message.includes("staff_authentication_required")
    ? "access_denied"
    : "query_failed";
}

function report(operation: string, message: string): void {
  console.error(`[staff-catalogue:${operation}] ${message}`);
}

export async function getStaffCatalogueItems(
  client: SupabaseClient,
  search?: string,
): Promise<StaffCatalogueResult<StaffCatalogueItem[]>> {
  const { data, error } = await client.rpc("get_staff_catalogue_items", {
    p_search: search?.trim() || null,
  });
  if (error) {
    report("list", error.message);
    return { ok: false, code: errorCode(error.message) };
  }

  const parsed = z.array(staffCatalogueItemSchema).safeParse(data);
  if (!parsed.success) {
    report("list", "Supabase returned an unexpected response shape.");
    return { ok: false, code: "invalid_response" };
  }
  return { ok: true, data: parsed.data };
}

export async function getStaffCatalogueItem(
  client: SupabaseClient,
  itemId: string,
): Promise<StaffCatalogueResult<StaffCatalogueItem | null>> {
  const { data, error } = await client.rpc("get_staff_catalogue_item", {
    p_item_id: itemId,
  });
  if (error) {
    report("detail", error.message);
    return { ok: false, code: errorCode(error.message) };
  }

  const candidate = Array.isArray(data) ? data[0] ?? null : null;
  if (candidate === null) {
    return { ok: true, data: null };
  }
  const parsed = staffCatalogueItemSchema.safeParse(candidate);
  if (!parsed.success) {
    report("detail", "Supabase returned an unexpected response shape.");
    return { ok: false, code: "invalid_response" };
  }
  return { ok: true, data: parsed.data };
}

export async function getStaffCatalogueReferenceData(
  client: SupabaseClient,
): Promise<StaffCatalogueResult<StaffCatalogueReferenceData>> {
  const { data, error } = await client.rpc(
    "get_staff_catalogue_reference_data",
  );
  if (error) {
    report("references", error.message);
    return { ok: false, code: errorCode(error.message) };
  }

  const parsed = referenceDataSchema.safeParse(data);
  if (!parsed.success) {
    report("references", "Supabase returned an unexpected response shape.");
    return { ok: false, code: "invalid_response" };
  }
  return { ok: true, data: parsed.data };
}
