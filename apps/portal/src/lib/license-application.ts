import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";

const option = z.object({ code: z.string(), label: z.string() });
export const applicationOptionsSchema = z.object({
  endorsements: z.array(option.extend({ description: z.string() })), jurisdictions: z.array(option), license_classes: z.array(option),
});
export type ApplicationOptions = z.infer<typeof applicationOptionsSchema>;

export async function getApplicationOptions(client: SupabaseClient) {
  const { data, error } = await client.rpc("get_public_license_application_options");
  if (error) return null; const parsed = applicationOptionsSchema.safeParse(data); return parsed.success ? parsed.data : null;
}
