import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";

const orderLineSchema = z.object({
  control_profile_code: z.string(),
  id: z.string().uuid(),
  item_code: z.string(),
  item_name: z.string(),
  line_number: z.number().int().positive(),
  pricing_status: z.enum(["pending", "configured"]),
  quantity_approved: z.coerce.number().positive().nullable(),
  quantity_fulfilled: z.coerce.number().nonnegative(),
  quantity_requested: z.coerce.number().positive(),
  status: z.string(),
  unit_code: z.string(),
  unit_price_minor: z.number().int().nonnegative().safe().nullable(),
  version: z.number().int().positive().safe().optional(),
  requires_serial_tracking: z.boolean().optional(),
  requires_staff_review: z.boolean().optional(),
  requires_transaction_approval: z.boolean().optional(),
  review_reason_codes: z.array(z.string()).optional(),
});

const orderSchema = z.object({
  currency_code: z.string(),
  dealer_notes: z.string(),
  dealer_reference: z.string(),
  fulfillment_mode: z.enum(["collection", "delivery", "consignment"]),
  id: z.string().uuid(),
  license_reference: z.string().nullable(),
  lines: z.array(orderLineSchema),
  ordering_party_id: z.string().uuid(),
  ordering_party_name: z.string(),
  public_reference: z.string(),
  status: z.string(),
  submitted_at: z.string(),
  version: z.number().int().positive().safe(),
});

const dealerAuthorizationOptionSchema = z.object({
  id: z.string().uuid(),
  jurisdiction_code: z.string(),
  jurisdiction_label: z.string(),
  public_reference: z.string(),
});

const licenseOptionSchema = z.object({
  class_label: z.string(),
  id: z.string().uuid(),
  public_reference: z.string(),
});

const orderRepresentationSchema = z.object({
  dealer_authorizations: z.array(dealerAuthorizationOptionSchema),
  licenses: z.array(licenseOptionSchema),
  party_id: z.string().uuid(),
  party_name: z.string(),
});

const orderItemSchema = z.object({
  availability_label: z.string(),
  control_label: z.string(),
  display_name: z.string(),
  id: z.string().uuid(),
  item_code: z.string(),
  pricing_status: z.literal("pending"),
  unit_code: z.string(),
  unit_name: z.string(),
});

const dealerOrderReferenceDataSchema = z.object({
  items: z.array(orderItemSchema),
  representations: z.array(orderRepresentationSchema),
});

export type OrderRecord = z.infer<typeof orderSchema>;
export type DealerOrderReferenceData = z.infer<
  typeof dealerOrderReferenceDataSchema
>;

export type OrderResult<T> =
  | { ok: true; data: T }
  | {
      ok: false;
      code: "access_denied" | "invalid_response" | "query_failed";
    };

function errorCode(message: string): "access_denied" | "query_failed" {
  return message.includes("scope_denied") ||
    message.includes("permission_denied") ||
    message.includes("authentication_required")
    ? "access_denied"
    : "query_failed";
}

function report(surface: string, operation: string, message: string) {
  console.error(`[${surface}-orders:${operation}] ${message}`);
}

async function parseOrderList(
  client: SupabaseClient,
  functionName: "get_dealer_orders" | "get_staff_order_queue",
  parameters?: { p_search: string | null },
  surface: "dealer" | "staff" = "dealer",
): Promise<OrderResult<OrderRecord[]>> {
  const { data, error } = await client.rpc(functionName, parameters);
  if (error) {
    report(surface, "list", error.message);
    return { ok: false, code: errorCode(error.message) };
  }
  const parsed = z.array(orderSchema).safeParse(data);
  if (!parsed.success) {
    report(surface, "list", "Supabase returned an unexpected response shape.");
    return { ok: false, code: "invalid_response" };
  }
  return { ok: true, data: parsed.data };
}

export function getDealerOrders(client: SupabaseClient) {
  return parseOrderList(client, "get_dealer_orders");
}

export async function getDealerOrder(
  client: SupabaseClient,
  orderId: string,
): Promise<OrderResult<OrderRecord | null>> {
  const { data, error } = await client.rpc("get_dealer_order", {
    p_order_id: orderId,
  });
  if (error) {
    report("dealer", "detail", error.message);
    return { ok: false, code: errorCode(error.message) };
  }
  const candidate = Array.isArray(data) ? data[0] ?? null : null;
  if (!candidate) return { ok: true, data: null };
  const parsed = orderSchema.safeParse(candidate);
  return parsed.success
    ? { ok: true, data: parsed.data }
    : { ok: false, code: "invalid_response" };
}

export async function getDealerOrderReferenceData(
  client: SupabaseClient,
): Promise<OrderResult<DealerOrderReferenceData>> {
  const { data, error } = await client.rpc("get_dealer_order_reference_data");
  if (error) {
    report("dealer", "references", error.message);
    return { ok: false, code: errorCode(error.message) };
  }
  const parsed = dealerOrderReferenceDataSchema.safeParse(data);
  return parsed.success
    ? { ok: true, data: parsed.data }
    : { ok: false, code: "invalid_response" };
}

export function getStaffOrders(client: SupabaseClient, search?: string) {
  return parseOrderList(
    client,
    "get_staff_order_queue",
    { p_search: search?.trim() || null },
    "staff",
  );
}

export async function getStaffOrder(
  client: SupabaseClient,
  orderId: string,
): Promise<OrderResult<OrderRecord | null>> {
  const { data, error } = await client.rpc("get_staff_order", {
    p_order_id: orderId,
  });
  if (error) {
    report("staff", "detail", error.message);
    return { ok: false, code: errorCode(error.message) };
  }
  const candidate = Array.isArray(data) ? data[0] ?? null : null;
  if (!candidate) return { ok: true, data: null };
  const parsed = orderSchema.safeParse(candidate);
  return parsed.success
    ? { ok: true, data: parsed.data }
    : { ok: false, code: "invalid_response" };
}
