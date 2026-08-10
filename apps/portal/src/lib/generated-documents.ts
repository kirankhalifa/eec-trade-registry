import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";

const documentSchema = z.object({
  checksum_sha256: z.string().length(64), document_type: z.string(), generated_at: z.string(), id: z.guid(),
  public_reference: z.string(), source_record_id: z.guid(), source_record_type: z.string(),
  source_version: z.number().int().positive(),
});

export type GeneratedDocument = z.infer<typeof documentSchema>;

export async function getGeneratedDocuments(client: SupabaseClient) {
  const { data, error } = await client.rpc("get_staff_generated_documents");
  if (error) return { ok: false as const, denied: error.message.includes("permission_denied") };
  const parsed = z.array(documentSchema).safeParse(data);
  return parsed.success ? { ok: true as const, data: parsed.data } : { ok: false as const, denied: false };
}

export const generatedDocumentDetailSchema = documentSchema.extend({ snapshot_payload: z.record(z.string(), z.unknown()) });
