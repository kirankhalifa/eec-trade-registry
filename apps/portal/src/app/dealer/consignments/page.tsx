import { submitConsignmentReportAction } from "@/app/dealer/consignments/actions";
import { ConsignmentNotice } from "@/components/consignment-notice";
import { DealerAccessDenied } from "@/components/dealer-access-denied";
import { getDealerConsignmentWorkspace } from "@/lib/consignments";
import { requireDealerSession } from "@/lib/dealer-auth";
import { getDefaultLocale } from "@/lib/env";

interface PageProps { searchParams: Promise<{ error?: string; notice?: string }> }
function quantity(value: number) {
  return new Intl.NumberFormat(undefined, { maximumFractionDigits: 3 }).format(value);
}

export default async function DealerConsignmentsPage({ searchParams }: PageProps) {
  const parameters = await searchParams;
  const { client } = await requireDealerSession();
  const result = await getDealerConsignmentWorkspace(client);
  if (!result.ok && result.code === "access_denied") return <main className="dealer-main"><DealerAccessDenied /></main>;
  if (!result.ok) return <main className="dealer-main"><section className="notice-panel"><h1>Consignment register unavailable</h1><p>No spreadsheet, message, or local cache was substituted for the registry.</p></section></main>;
  const locale = getDefaultLocale();
  const active = result.data.issues.filter((issue) => issue.status === "active");
  const outstanding = active.reduce((sum, issue) => sum + issue.quantity_outstanding, 0);
  return (
    <main className="dealer-main">
      <header className="dealer-page-header">
        <div><p className="eyebrow">Authenticated representative - custody reporting</p><h1>Consigned stock</h1><p>Review stock held for the owner and submit periodic observations. Staff acceptance is a separate step and only accepted reports affect the authoritative ledger.</p></div>
      </header>
      <ConsignmentNotice error={parameters.error} notice={parameters.notice} />
      <section className="inventory-summary" aria-label="Dealer consignment totals"><article><span>Active custody issues</span><strong>{active.length}</strong></article><article><span>Units outstanding</span><strong>{quantity(outstanding)}</strong></article><article><span>Reports awaiting review</span><strong>{result.data.issues.reduce((sum, issue) => sum + issue.reports.filter((report) => report.status === "submitted").length, 0)}</strong></article></section>

      <div className="order-list">{result.data.issues.map((issue) => {
        const hasPending = issue.reports.some((report) => report.status === "submitted");
        return <article className="order-card" key={issue.id}>
          <header><div><span className={`order-status order-status-${issue.status}`}>{issue.status}</span><h2>{issue.public_reference}</h2><p>{issue.item_code} - {issue.item_name}</p></div><strong>{quantity(issue.quantity_outstanding)} outstanding</strong></header>
          <dl className="order-facts"><div><dt>Agreement</dt><dd>{issue.agreement_reference}</dd></div><div><dt>Issued</dt><dd>{quantity(issue.quantity_issued)}</dd></div><div><dt>Accepted sold / returned</dt><dd>{quantity(issue.quantity_sold)} / {quantity(issue.quantity_returned)}</dd></div><div><dt>Issued at</dt><dd>{new Date(issue.issued_at).toLocaleString(locale)}</dd></div></dl>
          {issue.status === "active" && !hasPending && <form action={submitConsignmentReportAction} className="inventory-command-form inventory-receipt-form"><input name="consignment_issue_id" type="hidden" value={issue.id} /><label className="field"><span>Sold since last accepted report</span><input defaultValue="0" min="0" name="quantity_sold" required step="0.001" type="number" /></label><label className="field"><span>Returning to owner</span><input defaultValue="0" min="0" name="quantity_returned" required step="0.001" type="number" /></label><label className="field"><span>Reported lost</span><input defaultValue="0" min="0" name="quantity_lost" required step="0.001" type="number" /></label><label className="field"><span>Reported damaged</span><input defaultValue="0" min="0" name="quantity_damaged" required step="0.001" type="number" /></label><label className="field"><span>Observed on hand after these changes</span><input defaultValue={issue.quantity_outstanding} min="0" name="observed_on_hand" required step="0.001" type="number" /></label><label className="field"><span>Count notes</span><textarea maxLength={4000} name="report_notes" rows={3} /></label><label className="field"><span>Submission reason / evidence</span><textarea maxLength={500} name="reason" required rows={3} /></label><button className="button button-primary" type="submit">Submit custody report</button></form>}
          {hasPending && <p className="dealer-policy-note">A report is awaiting staff review. Submit another after it is accepted or rejected.</p>}
          {issue.reports.length > 0 && <section className="dealer-record-section"><div className="dealer-section-heading"><h3>Report history</h3><span>{issue.reports.length}</span></div><div className="dealer-record-grid">{issue.reports.map((report) => <article className="dealer-record-card" key={report.public_reference}><div className="dealer-record-status"><span className={report.status === "accepted" ? "dealer-status-current" : "dealer-status-inactive"}>{report.status}</span><strong>{report.public_reference}</strong></div><p>Sold {quantity(report.quantity_sold)} - returned {quantity(report.quantity_returned)} - lost {quantity(report.quantity_lost)} - damaged {quantity(report.quantity_damaged)} - observed {quantity(report.observed_on_hand)}</p><small>{new Date(report.submitted_at).toLocaleString(locale)}</small></article>)}</div></section>}
        </article>;
      })}</div>
      {result.data.issues.length === 0 && <section className="empty-state"><p className="eyebrow">No custody issues</p><h2>No consigned stock is assigned</h2><p>This view only shows current database records for organizations you actively represent.</p></section>}
      <aside className="dealer-policy-note"><strong>Observation is not settlement</strong><p>Submitting a report records your observation. Stock changes only when authorized staff accept a fully reconciled report. Lost and damaged quantities require a separate exception process.</p></aside>
    </main>
  );
}
