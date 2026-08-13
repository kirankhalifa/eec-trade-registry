import Link from "next/link";

import {
  acceptConsignmentReportAction,
  changeConsignmentAgreementStatusAction,
  createConsignmentAgreementAction,
  issueConsignmentStockAction,
  rejectConsignmentReportAction,
} from "@/app/staff/consignments/actions";
import { ConsignmentNotice } from "@/components/consignment-notice";
import { StaffAccessDenied } from "@/components/staff-access-denied";
import { getStaffConsignmentWorkspace } from "@/lib/consignments";
import { getDefaultLocale } from "@/lib/env";
import { requireStaffSession } from "@/lib/staff-auth";

interface PageProps { searchParams: Promise<{ error?: string; notice?: string }> }
function quantity(value: number) {
  return new Intl.NumberFormat(undefined, { maximumFractionDigits: 3 }).format(value);
}

export default async function StaffConsignmentsPage({ searchParams }: PageProps) {
  const parameters = await searchParams;
  const { client } = await requireStaffSession();
  const result = await getStaffConsignmentWorkspace(client);
  if (!result.ok && result.code === "access_denied") return <main className="staff-main"><StaffAccessDenied /></main>;
  if (!result.ok) return <main className="staff-main"><section className="notice-panel"><h1>Consignment desk unavailable</h1><p>No external record or calculated fallback was substituted.</p></section></main>;
  const workspace = result.data;
  const locale = getDefaultLocale();
  const pending = workspace.reports.filter((report) => report.status === "submitted");
  const activeAgreements = workspace.agreements.filter((agreement) => agreement.status === "active");
  const outstanding = workspace.issues.reduce((sum, issue) => sum + issue.quantity_outstanding, 0);
  const localDateTime = new Date().toISOString().slice(0, 16);

  return (
    <main className="staff-main">
      <header className="staff-page-header">
        <div><p className="eyebrow">Authenticated staff - retained ownership</p><h1>Consignment desk</h1><p>Create agreements, move fungible stock into dealer custody, reconcile dealer observations, and preserve every custody movement in the inventory ledger.</p></div>
        <div className="staff-button-row">
          <Link className="button button-secondary" href="/dealer/consignments" target="_blank">Dealer view</Link>
        </div>
      </header>
      <ConsignmentNotice error={parameters.error} notice={parameters.notice} />
      <section className="inventory-summary" aria-label="Consignment totals">
        <article><span>Active agreements</span><strong>{activeAgreements.length}</strong></article>
        <article><span>Open custody issues</span><strong>{workspace.issues.filter((issue) => issue.status === "active").length}</strong></article>
        <article><span>Units in custody</span><strong>{quantity(outstanding)}</strong></article>
        <article><span>Reports awaiting review</span><strong>{pending.length}</strong></article>
      </section>

      {workspace.capabilities.can_manage_agreements && (
        <section className="inventory-section">
          <div className="inventory-section-heading"><div><p className="eyebrow">Authority record</p><h2>Create agreement</h2></div><p>Only an active warehouse owner and currently authorized dealer can be selected.</p></div>
          <form action={createConsignmentAgreementAction} className="inventory-command-form inventory-receipt-form">
            <label className="field"><span>Owner</span><select name="owner_party_id" required><option value="">Choose owner</option>{workspace.owners.map((party) => <option key={party.id} value={party.id}>{party.display_name}</option>)}</select></label>
            <label className="field"><span>Consignee</span><select name="consignee_party_id" required><option value="">Choose authorized dealer</option>{workspace.consignees.map((party) => <option key={party.id} value={party.id}>{party.display_name}</option>)}</select></label>
            <label className="field"><span>Jurisdiction</span><select name="jurisdiction_id" required><option value="">Choose jurisdiction</option>{workspace.jurisdictions.map((item) => <option key={item.id} value={item.id}>{item.display_name}</option>)}</select></label>
            <label className="field"><span>Effective from</span><input defaultValue={localDateTime} name="effective_from" required type="datetime-local" /></label>
            <label className="field"><span>Effective until (optional)</span><input name="effective_until" type="datetime-local" /></label>
            <label className="field"><span>Terms summary</span><textarea maxLength={4000} name="terms_summary" rows={3} /></label>
            <label className="field"><span>Creation reason</span><textarea maxLength={500} name="reason" required rows={3} /></label>
            <button className="button button-primary" type="submit">Create agreement</button>
          </form>
        </section>
      )}

      {workspace.capabilities.can_issue && (
        <section className="inventory-section">
          <div className="inventory-section-heading"><div><p className="eyebrow">Ledger movement</p><h2>Issue stock to custody</h2></div><p>The database rechecks agreement dates, ownership, warehouse scope, stock, and active reservations.</p></div>
          <form action={issueConsignmentStockAction} className="inventory-command-form inventory-receipt-form">
            <label className="field"><span>Active agreement</span><select name="agreement_id" required><option value="">Choose agreement</option>{activeAgreements.map((agreement) => <option key={agreement.id} value={agreement.id}>{agreement.public_reference} - {agreement.owner_name} to {agreement.consignee_name}</option>)}</select></label>
            <label className="field"><span>Source stock</span><select name="source_inventory_account_id" required><option value="">Choose available stock</option>{workspace.source_accounts.map((account) => <option key={account.id} value={account.id}>{account.warehouse_name} / {account.location_name} / {account.item_code} - {quantity(account.available)} available</option>)}</select></label>
            <label className="field"><span>Quantity</span><input min="0.001" name="quantity" required step="0.001" type="number" /></label>
            <label className="field"><span>Issue reason</span><textarea maxLength={500} name="reason" required rows={3} /></label>
            <button className="button button-primary" type="submit">Issue into dealer custody</button>
          </form>
        </section>
      )}

      <section className="inventory-section">
        <div className="inventory-section-heading"><div><p className="eyebrow">Effective authority</p><h2>Agreement register</h2></div><p>Closing is rejected while any issued quantity remains in dealer custody.</p></div>
        <div className="inventory-transaction-list">{workspace.agreements.map((agreement) => (
          <article className="inventory-transaction-card" key={agreement.id}>
            <div><span className={`order-status order-status-${agreement.status}`}>{agreement.status}</span><h3>{agreement.public_reference}</h3><p>{agreement.owner_name} to {agreement.consignee_name} - {agreement.jurisdiction_name}</p><small>{new Date(agreement.effective_from).toLocaleString(locale)}{agreement.effective_until ? ` to ${new Date(agreement.effective_until).toLocaleString(locale)}` : " - no recorded end"}</small>{agreement.terms_summary && <p>{agreement.terms_summary}</p>}</div>
            {workspace.capabilities.can_manage_agreements && agreement.status !== "closed" && <form action={changeConsignmentAgreementStatusAction} className="inventory-command-form"><input name="id" type="hidden" value={agreement.id} /><input name="expected_version" type="hidden" value={agreement.version} /><label className="field"><span>New status</span><select name="status">{(agreement.status === "active" ? ["suspended", "closed"] : ["active", "closed"]).map((status) => <option key={status}>{status}</option>)}</select></label><label className="field"><span>Audit reason</span><input maxLength={500} name="reason" required /></label><button className="button button-secondary" type="submit">Change status</button></form>}
          </article>
        ))}</div>
        {workspace.agreements.length === 0 && <p className="empty-state">No consignment agreement has been created.</p>}
      </section>

      <section className="inventory-section">
        <div className="inventory-section-heading"><div><p className="eyebrow">Dealer observations</p><h2>Report review queue</h2></div><p>Lost or damaged reports are deliberately held for a future exception workflow.</p></div>
        <div className="inventory-transaction-list">{workspace.reports.map((report) => (
          <article className="inventory-transaction-card" key={report.id}>
            <div><span className={`order-status order-status-${report.status}`}>{report.status}</span><h3>{report.public_reference}</h3><p>{report.issue_reference} / {report.item_code} / {report.consignee_name}</p><small>Sold {quantity(report.quantity_sold)} - returned {quantity(report.quantity_returned)} - lost {quantity(report.quantity_lost)} - damaged {quantity(report.quantity_damaged)} - observed {quantity(report.observed_on_hand)} at {new Date(report.submitted_at).toLocaleString(locale)}</small>{report.report_notes && <p>{report.report_notes}</p>}</div>
            {workspace.capabilities.can_review && report.status === "submitted" && <div className="inventory-reservation-list">
              <form action={acceptConsignmentReportAction} className="inventory-command-form"><input name="id" type="hidden" value={report.id} /><input name="expected_version" type="hidden" value={report.version} />{report.quantity_returned > 0 && <label className="field"><span>Authorized return account</span><select name="return_inventory_account_id" required><option value="">Choose destination</option>{workspace.return_accounts.filter((account) => account.item_id === report.item_id).map((account) => <option key={account.id} value={account.id}>{account.warehouse_name} / {account.location_name}</option>)}</select></label>}<label className="field"><span>Acceptance evidence</span><input maxLength={500} name="reason" required /></label><button className="button button-primary" type="submit">Accept and settle</button></form>
              <form action={rejectConsignmentReportAction} className="inventory-command-form"><input name="id" type="hidden" value={report.id} /><input name="expected_version" type="hidden" value={report.version} /><label className="field"><span>Rejection reason</span><input maxLength={500} name="reason" required /></label><button className="button button-secondary" type="submit">Reject without settlement</button></form>
            </div>}
          </article>
        ))}</div>
        {workspace.reports.length === 0 && <p className="empty-state">No dealer custody report has been submitted.</p>}
      </section>

      <section className="inventory-section"><div className="inventory-section-heading"><div><p className="eyebrow">Retained ownership</p><h2>Custody positions</h2></div><p>Outstanding quantity is a database projection of accepted ledger-backed settlements.</p></div><div className="inventory-transaction-list">{workspace.issues.map((issue) => <article className="inventory-transaction-card" key={issue.id}><div><span className={`order-status order-status-${issue.status}`}>{issue.status}</span><h3>{issue.public_reference}</h3><p>{issue.item_code} - {issue.item_name} / {issue.consignee_name}</p><small>Issued {quantity(issue.quantity_issued)} - sold {quantity(issue.quantity_sold)} - returned {quantity(issue.quantity_returned)} - outstanding {quantity(issue.quantity_outstanding)} / {new Date(issue.issued_at).toLocaleString(locale)}</small></div></article>)}</div>{workspace.issues.length === 0 && <p className="empty-state">No stock is currently registered in consignment custody.</p>}</section>
    </main>
  );
}
