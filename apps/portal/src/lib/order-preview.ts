import { z } from "zod";

const nullableNumber = z.coerce.number().nullable();

export const tradeOrderPreviewSchema = z.object({
  channel: z.enum(["staff_assisted_business", "direct_individual"]),
  channel_label: z.string(),
  currency_code: z.string().nullable(),
  lines: z.array(
    z.object({
      base_price_minor: nullableNumber,
      currency_code: z.string().nullable(),
      item_code: z.string(),
      item_id: z.guid(),
      item_name: z.string(),
      multiplier_basis_points: z.coerce.number().int().nullable(),
      price_source: z.string(),
      quantity: z.coerce.number().positive(),
      unit: z.string().nullable(),
      unit_price_minor: nullableNumber,
      weekly_limit: nullableNumber,
      weekly_remaining: nullableNumber,
      weekly_used: nullableNumber,
    }),
  ),
  reservation_message: z.string(),
  total_amount_minor: nullableNumber,
  valid: z.boolean(),
  warnings: z.array(z.string()),
});
export type TradeOrderPreview = z.infer<typeof tradeOrderPreviewSchema>;

export interface GuidedOrderState {
  error?: string;
  fingerprint?: string;
  preview?: TradeOrderPreview;
}
