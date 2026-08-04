import { z } from "zod";

const machineCodeSchema = z
  .string()
  .trim()
  .regex(/^[A-Z0-9][A-Z0-9_-]{1,31}$/);
const slugSchema = z
  .string()
  .trim()
  .regex(/^[a-z0-9][a-z0-9-]{1,79}$/);
const referenceCodeSchema = z
  .string()
  .trim()
  .regex(/^[a-z0-9][a-z0-9_-]{0,49}$/);
const reasonSchema = z.string().trim().min(3).max(500);

const mutableCatalogueFieldsSchema = z.object({
  displayName: z.string().trim().min(1).max(160),
  description: z.string().trim().max(4000),
  categoryCode: referenceCodeSchema,
  unitCode: referenceCodeSchema,
  inventoryMode: z.enum(["fungible", "serialized"]),
  internalNotes: z.string().trim().max(4000),
  reason: reasonSchema,
});

export const createCatalogueItemSchema = mutableCatalogueFieldsSchema.extend({
  itemCode: machineCodeSchema,
  slug: slugSchema,
});

export const updateCatalogueItemSchema = mutableCatalogueFieldsSchema.extend({
  itemId: z.guid(),
  expectedVersion: z.coerce.number().int().positive().safe(),
});

export const setCatalogueStatusSchema = z.object({
  itemId: z.guid(),
  expectedVersion: z.coerce.number().int().positive().safe(),
  status: z.enum(["active", "archived"]),
  reason: reasonSchema,
});

export type CreateCatalogueItemInput = z.infer<
  typeof createCatalogueItemSchema
>;
export type UpdateCatalogueItemInput = z.infer<
  typeof updateCatalogueItemSchema
>;
export type SetCatalogueStatusInput = z.infer<
  typeof setCatalogueStatusSchema
>;

function text(formData: FormData, name: string): string {
  const value = formData.get(name);
  return typeof value === "string" ? value : "";
}

export function readCreateCatalogueItemForm(formData: FormData) {
  return createCatalogueItemSchema.safeParse({
    itemCode: text(formData, "item_code").toUpperCase(),
    slug: text(formData, "slug").toLowerCase(),
    displayName: text(formData, "display_name"),
    description: text(formData, "description"),
    categoryCode: text(formData, "category_code"),
    unitCode: text(formData, "unit_code"),
    inventoryMode: text(formData, "inventory_mode"),
    internalNotes: text(formData, "internal_notes"),
    reason: text(formData, "reason"),
  });
}

export function readUpdateCatalogueItemForm(formData: FormData) {
  return updateCatalogueItemSchema.safeParse({
    itemId: text(formData, "item_id"),
    expectedVersion: text(formData, "expected_version"),
    displayName: text(formData, "display_name"),
    description: text(formData, "description"),
    categoryCode: text(formData, "category_code"),
    unitCode: text(formData, "unit_code"),
    inventoryMode: text(formData, "inventory_mode"),
    internalNotes: text(formData, "internal_notes"),
    reason: text(formData, "reason"),
  });
}

export function readSetCatalogueStatusForm(formData: FormData) {
  return setCatalogueStatusSchema.safeParse({
    itemId: text(formData, "item_id"),
    expectedVersion: text(formData, "expected_version"),
    status: text(formData, "status"),
    reason: text(formData, "reason"),
  });
}
