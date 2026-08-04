import { z } from "zod";

import { CatalogueConfigurationError, getPublicSupabaseClient } from "@/lib/supabase";
import type { CatalogueQuery } from "@/lib/query";

const numericValueSchema = z
  .union([z.number(), z.string()])
  .transform((value, context) => {
    const parsed = Number(value);
    if (!Number.isFinite(parsed)) {
      context.addIssue({ code: "custom", message: "Expected a finite number." });
      return z.NEVER;
    }
    return parsed;
  });

const publicCatalogueItemSchema = z.object({
  availability_code: z.string(),
  availability_description: z.string(),
  availability_label: z.string(),
  bulk_minimum: numericValueSchema.nullable(),
  category_code: z.string(),
  category_name: z.string(),
  control_code: z.string(),
  control_description: z.string(),
  control_label: z.string(),
  currency_code: z.string().nullable(),
  currency_symbol: z.string().nullable(),
  currency_symbol_position: z.enum(["prefix", "suffix"]).nullable(),
  description: z.string(),
  display_name: z.string(),
  generated_at: z.string(),
  item_code: z.string(),
  minor_unit_scale: z.number().int().min(0).max(6).nullable(),
  order_increment: numericValueSchema,
  price_amount_minor: z.number().int().safe().nullable(),
  published_at: z.string(),
  requirement_summary: z.string(),
  slug: z.string(),
  tags: z.array(z.string()),
  unit_code: z.string(),
  unit_name: z.string(),
  unit_symbol: z.string().nullable(),
});

const publicCatalogueCategorySchema = z.object({
  code: z.string(),
  display_name: z.string(),
  item_count: z.number().int().nonnegative(),
});

export type PublicCatalogueItem = z.infer<typeof publicCatalogueItemSchema>;
export type PublicCatalogueCategory = z.infer<
  typeof publicCatalogueCategorySchema
>;

export type CatalogueResult<T> =
  | { ok: true; data: T }
  | {
      ok: false;
      code: "not_configured" | "query_failed" | "invalid_response";
    };

function reportQueryFailure(operation: string, message: string): void {
  console.error(`[catalogue:${operation}] ${message}`);
}

export async function getPublicCatalogue(
  query: CatalogueQuery,
): Promise<CatalogueResult<PublicCatalogueItem[]>> {
  try {
    const client = getPublicSupabaseClient();
    const { data, error } = await client.rpc("get_public_catalogue", {
      p_category_code: query.category,
      p_search: query.search,
    });

    if (error) {
      reportQueryFailure("list", error.message);
      return { ok: false, code: "query_failed" };
    }

    const parsed = z.array(publicCatalogueItemSchema).safeParse(data);
    if (!parsed.success) {
      reportQueryFailure("list", "Supabase returned an unexpected response shape.");
      return { ok: false, code: "invalid_response" };
    }

    return { ok: true, data: parsed.data };
  } catch (error) {
    if (error instanceof CatalogueConfigurationError) {
      return { ok: false, code: "not_configured" };
    }
    reportQueryFailure("list", "The catalogue query failed unexpectedly.");
    return { ok: false, code: "query_failed" };
  }
}

export async function getPublicCatalogueCategories(): Promise<
  CatalogueResult<PublicCatalogueCategory[]>
> {
  try {
    const client = getPublicSupabaseClient();
    const { data, error } = await client.rpc("get_public_catalogue_categories");

    if (error) {
      reportQueryFailure("categories", error.message);
      return { ok: false, code: "query_failed" };
    }

    const parsed = z.array(publicCatalogueCategorySchema).safeParse(data);
    if (!parsed.success) {
      reportQueryFailure(
        "categories",
        "Supabase returned an unexpected response shape.",
      );
      return { ok: false, code: "invalid_response" };
    }

    return { ok: true, data: parsed.data };
  } catch (error) {
    if (error instanceof CatalogueConfigurationError) {
      return { ok: false, code: "not_configured" };
    }
    reportQueryFailure("categories", "The category query failed unexpectedly.");
    return { ok: false, code: "query_failed" };
  }
}

export async function getPublicCatalogueItem(
  slug: string,
): Promise<CatalogueResult<PublicCatalogueItem | null>> {
  try {
    const client = getPublicSupabaseClient();
    const { data, error } = await client.rpc("get_public_catalogue_item", {
      p_slug: slug,
    });

    if (error) {
      reportQueryFailure("detail", error.message);
      return { ok: false, code: "query_failed" };
    }

    const candidate = Array.isArray(data) ? data[0] ?? null : null;
    if (candidate === null) {
      return { ok: true, data: null };
    }

    const parsed = publicCatalogueItemSchema.safeParse(candidate);
    if (!parsed.success) {
      reportQueryFailure("detail", "Supabase returned an unexpected response shape.");
      return { ok: false, code: "invalid_response" };
    }

    return { ok: true, data: parsed.data };
  } catch (error) {
    if (error instanceof CatalogueConfigurationError) {
      return { ok: false, code: "not_configured" };
    }
    reportQueryFailure("detail", "The catalogue detail query failed unexpectedly.");
    return { ok: false, code: "query_failed" };
  }
}
