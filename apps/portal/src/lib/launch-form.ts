import { z } from "zod";

const text = (maximum: number) => z.string().trim().min(1).max(maximum);
const optionalGuid = z.union([z.literal(""), z.guid()]).transform((value) => value || null);
const optionalDate = z.union([z.literal(""), z.iso.datetime({ local: true })]).transform((value) => value || null);

function fields(form: FormData) {
  return Object.fromEntries(form.entries());
}

export const assistedOrderSchema = z.object({
  business_key: z.string().default(""), channel: z.enum(["staff_assisted_business", "direct_individual"]),
  contact_label: z.string().trim().max(300).default(""), direct_customer_id: optionalGuid,
  fulfillment_mode: z.enum(["collection", "delivery", "consignment"]), jurisdiction_id: optionalGuid,
  new_customer_name: z.string().trim().max(200).default(""), notes: z.string().trim().max(2000).default(""),
  reason: text(500),
});

export function readAssistedOrderForm(form: FormData) {
  const base = assistedOrderSchema.safeParse(fields(form));
  const lines = [1, 2, 3, 4, 5].flatMap((number) => {
    const item = form.get(`item_id_${number}`);
    const quantity = form.get(`quantity_${number}`);
    if (typeof item !== "string" || !item) return [];
    const parsed = z.object({ item_id: z.guid(), quantity: z.coerce.number().positive().max(1_000_000) }).safeParse({ item_id: item, quantity });
    return parsed.success ? [parsed.data] : [];
  });
  if (!base.success || lines.length === 0) return { success: false as const };
  return { success: true as const, data: { ...base.data, lines } };
}

export const decisionSchema = z.object({
  application_id: z.guid(), decision: z.enum(["approve", "deny"]), effective_from: optionalDate,
  expected_version: z.coerce.number().int().positive(), expires_at: optionalDate, holder_party_id: optionalGuid,
  initial_status_code: z.enum(["active", "provisional"]).default("active"), reason: text(500),
});

export const financeTermSchema = z.object({
  agreement_id: z.guid(), commission_percent: z.coerce.number().min(0).max(100), currency_code: text(12),
  effective_from: optionalDate, effective_until: optionalDate, reason: text(500),
});

export const settlementSchema = z.object({
  report_id: z.guid(), reason: text(500), unit_sale_price: z.coerce.number().int().nonnegative(),
});

export const paymentSchema = z.object({
  expected_version: z.coerce.number().int().positive(), payment_reference: text(200), reason: text(500), settlement_id: z.guid(),
});

export const fulfillmentSchema = z.object({
  asset_version: z.coerce.number().int().positive(), reason: text(500), reservation_id: z.guid(),
  reservation_version: z.coerce.number().int().positive(),
});

export const documentGenerationSchema = z.object({
  document_type: z.enum(["license_certificate", "order_confirmation", "unique_fulfillment_receipt", "consignment_statement"]),
  reason: text(500), source_record_id: z.guid(),
});

export const priceBindingSchema = z.object({
  binding_type: z.enum(["party", "license_class", "dealer_type", "jurisdiction", "channel_default"]),
  channel_code: z.enum(["dealer_portal", "staff_assisted_business", "direct_individual"]).optional(),
  effective_from: optionalDate, effective_until: optionalDate, priority: z.coerce.number().int().min(-1000).max(1000),
  reason: text(500), schedule_id: z.guid(), target_id: optionalGuid,
});

export function parse<T>(schema: z.ZodType<T>, form: FormData) {
  return schema.safeParse(fields(form));
}
