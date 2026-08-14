import Link from "next/link";

import { generateDocumentAction } from "@/app/staff/launch/actions";
import { StaffAccessDenied } from "@/components/staff-access-denied";
import { StaffNotice } from "@/components/staff-notice";
import { getLaunchWorkspace } from "@/lib/launch-workspace";
import { requireStaffSession } from "@/lib/staff-auth";

interface NewDocumentPageProps { searchParams: Promise<{ error?: string; notice?: string }> }

function DocumentForm({ documentType, label, options }: {
  documentType: "license_certificate" | "order_confirmation" | "unique_fulfillment_receipt" | "consignment_statement";
  label: string;
  options: Array<{ id: string; label: string }>;
}) {
  return (
    <form action={generateDocumentAction} className="inventory-command-form">
      <input name="document_type" type="hidden" value={documentType} />
      <input name="reason" type="hidden" value="Official snapshot generated through document workspace." />
      <h2>{label}</h2>
      {options.length ? <><label className="field"><span>Source record</span><select defaultValue="" name="source_record_id" required><option disabled value="">Choose a record</option>{options.map((option) => <option key={option.id} value={option.id}>{option.label}</option>)}</select></label><button className="button button-primary">Generate PDF</button></> : <p>No eligible source record is available.</p>}
    </form>
  );
}

export default async function NewDocumentPage({ searchParams }: NewDocumentPageProps) {
  const parameters = await searchParams;
  const { client } = await requireStaffSession();
  const result = await getLaunchWorkspace(client);
  if (!result.ok && result.denied) return <main className="staff-main"><StaffAccessDenied /></main>;
  if (!result.ok) return <main className="staff-main"><section className="notice-panel"><h1>Document generation unavailable</h1><p>No fallback source records were used.</p></section></main>;
  if (!result.data.capabilities.can_generate_documents) return <main className="staff-main"><StaffAccessDenied /></main>;
  const sources = result.data.document_sources;
  return (
    <main className="staff-main">
      <header className="staff-page-header"><div><p className="eyebrow">Official projections</p><h1>Generate a document</h1><p>Choose the record. The system freezes its authoritative version and renders a checksummed PDF snapshot.</p></div><Link className="button button-secondary" href="/staff/documents">Document archive</Link></header>
      <StaffNotice error={parameters.error} notice={parameters.notice} />
      <div className="inventory-command-grid">
        <DocumentForm documentType="license_certificate" label="License certificate" options={sources.licenses} />
        <DocumentForm documentType="order_confirmation" label="Order confirmation" options={sources.orders} />
        <DocumentForm documentType="unique_fulfillment_receipt" label="Unique-asset receipt" options={sources.fulfillments} />
        <DocumentForm documentType="consignment_statement" label="Consignment statement" options={sources.settlements} />
      </div>
    </main>
  );
}
