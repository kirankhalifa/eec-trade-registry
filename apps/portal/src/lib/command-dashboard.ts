import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";

const counterGroup = z.record(z.string(), z.number().int().nonnegative());
const dashboardSchema = z.object({
  access: counterGroup,
  capabilities: z.object({
    can_manage_access: z.boolean(),
    can_review_applications: z.boolean(),
  }),
  compliance: counterGroup,
  documents: counterGroup,
  finance: counterGroup,
  generated_at: z.string(),
  integrations: counterGroup,
  inventory: counterGroup,
  licensing: counterGroup,
  orders: counterGroup,
  recent_audit: z.array(z.object({
    action: z.string(), id: z.number(), occurred_at: z.string(),
    reason: z.string().nullable(), record_type: z.string(),
  })),
  recent_orders: z.array(z.object({
    channel: z.string(), customer: z.string(), id: z.guid(), reference: z.string(),
    status: z.string(), submitted_at: z.string(),
  })),
});

export type CommandDashboard = z.infer<typeof dashboardSchema>;

export async function getCommandDashboard(client: SupabaseClient) {
  const { data, error } = await client.rpc("get_staff_command_dashboard");
  if (error) {
    console.error(`[command-dashboard] ${error.message}`);
    return { ok: false as const, denied: error.message.includes("permission_denied") };
  }
  const parsed = dashboardSchema.safeParse(data);
  if (!parsed.success) {
    console.error("[command-dashboard] Unexpected authoritative response.");
    return { ok: false as const, denied: false };
  }
  return { ok: true as const, data: parsed.data };
}
