import Link from "next/link";
import { StaffAccessDenied } from "@/components/staff-access-denied";
import { StaffNotice } from "@/components/staff-notice";
import { getDefaultLocale } from "@/lib/env";
import { getGeneratedDocuments } from "@/lib/generated-documents";
import { requireStaffSession } from "@/lib/staff-auth";

export const dynamic = "force-dynamic";
interface Props { searchParams: Promise<{ notice?: string }> }

export default async function DocumentsPage({ searchParams }: Props) {
  const parameters=await searchParams; const { client }=await requireStaffSession(); const result=await getGeneratedDocuments(client);
  if (!result.ok&&result.denied) return <main className="staff-main"><StaffAccessDenied/></main>;
  if (!result.ok) return <main className="staff-main"><section className="notice-panel"><h1>Document archive unavailable</h1><p>No fallback document store was used.</p></section></main>;
  const locale=getDefaultLocale();
  return <main className="staff-main"><header className="staff-page-header"><div><p className="eyebrow">Authenticated staff · official projections</p><h1>Generated document archive</h1><p>Each PDF is rendered from a frozen Supabase snapshot and displays its source version and SHA-256 checksum.</p></div><div className="staff-button-row"><Link className="button button-primary" href="/staff/launch">Generate document</Link><Link className="button button-secondary" href="/staff/dashboard">Dashboard</Link></div></header><StaffNotice notice={parameters.notice}/><div className="inventory-reservation-list">{result.data.map((document)=><article className="inventory-reservation-card" key={document.id}><header><div><span className="staff-status staff-status-active">{document.document_type.replaceAll("_"," ")}</span><h3>{document.public_reference}</h3></div><Link className="button button-primary" href={`/staff/documents/${document.id}/download`}>Download PDF</Link></header><dl className="order-facts"><div><dt>Source</dt><dd>{document.source_record_type} v{document.source_version}</dd></div><div><dt>Generated</dt><dd>{new Date(document.generated_at).toLocaleString(locale)}</dd></div></dl><p><small>SHA-256 {document.checksum_sha256}</small></p></article>)}{result.data.length===0&&<p>No official document has been generated yet.</p>}</div></main>;
}
