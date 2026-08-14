import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";

const schema = z.object({
  items: z.array(z.object({ code: z.string(), id: z.guid(), label: z.string() })),
  rules: z.array(z.object({
    amount_minor: z.coerce.number().int().nonnegative(),
    currency_code: z.string(),
    direct_amount_minor: z.union([z.null(), z.coerce.number().int().nonnegative()]),
    item_id: z.guid(),
    schedule_id: z.guid(),
  })),
});

export type PricePreviewOptions = z.infer<typeof schema>;

export async function getPricePreviewOptions(client: SupabaseClient) {
  const { data, error } = await client.rpc("get_staff_price_preview_options");
  if (error) return { ok: false as const };
  const parsed = schema.safeParse(data);
  return parsed.success ? { ok: true as const, data: parsed.data } : { ok: false as const };
}
