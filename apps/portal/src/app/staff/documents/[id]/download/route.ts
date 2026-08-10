import { generatedDocumentDetailSchema } from "@/lib/generated-documents";
import { buildOfficialPdf } from "@/lib/official-pdf";
import { createServerSupabaseClient } from "@/lib/supabase-server";

export const dynamic = "force-dynamic";

export async function GET(_request: Request, context: { params: Promise<{ id: string }> }) {
  const { id } = await context.params;
  const client = await createServerSupabaseClient(); const { data: claims, error: claimError } = await client.auth.getClaims();
  if (claimError || typeof claims?.claims?.sub !== "string") return new Response("Authentication required", { status: 401 });
  const { data, error } = await client.rpc("get_staff_generated_document", { p_document_id: id });
  if (error) return new Response(error.message.includes("permission_denied") ? "Access denied" : "Document unavailable", { status: error.message.includes("permission_denied") ? 403 : 503 });
  const parsed = generatedDocumentDetailSchema.safeParse(data); if (!parsed.success) return new Response("Document not found", { status: 404 });
  const bytes = await buildOfficialPdf(parsed.data);
  return new Response(Buffer.from(bytes), { headers: {
    "Cache-Control": "private, no-store", "Content-Disposition": `attachment; filename="${parsed.data.public_reference}.pdf"`,
    "Content-Type": "application/pdf", "X-Content-Type-Options": "nosniff",
  }});
}
