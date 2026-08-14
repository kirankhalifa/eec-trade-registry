import Link from "next/link";

import {
  configureFinanceTermsAction,
  createSettlementAction,
  markSettlementPaidAction,
} from "@/app/staff/launch/actions";
import { StaffAccessDenied } from "@/components/staff-access-denied";
import { StaffNotice } from "@/components/staff-notice";
import { getLaunchWorkspace } from "@/lib/launch-workspace";
import { REGISTRY_CONFIG } from "@/lib/registry-config";
import { requireStaffSession } from "@/lib/staff-auth";

interface FinancePageProps { searchParams: Promise<{ error?: string; notice?: string }> }

export default async function ConsignmentFinancePage({ searchParams }: FinancePageProps) {
  const parameters = await searchParams;
  const { client } = await requireStaffSession();
  const result = await getLaunchWorkspace(client);
  if (!result.ok && result.denied) return <main className="staff-main"><StaffAccessDenied /></main>;
  if (!result.ok) return <main className="staff-main"><section className="notice-panel"><h1>Consignment finance unavailable</h1><p>No fallback settlement state was used.</p></section></main>;
  const workspace = result.data;
  if (!workspace.capabilities.can_manage_finance) return <main className="staff-main"><StaffAccessDenied /></main>;

  return (
    <main className="staff-main">
      <header className="staff-page-header"><div><p className="eyebrow">Consignment finance</p><h1>Commission and settlement</h1><p>Set the commission once, then freeze each accepted sales report into an auditable settlement.</p></div><div className="staff-button-row"><Link className="button button-secondary" href="/staff/consignments">Custody desk</Link><Link className="button button-secondary" href="/staff/launch">Quick actions</Link></div></header>
      <StaffNotice error={parameters.error} notice={parameters.notice} />

      <section className="inventory-section">
        <div className="inventory-section-heading"><div><p className="eyebrow">Agreement terms</p><h2>Set commission</h2></div><p>All settlements use {REGISTRY_CONFIG.currency.label}. Dates are optional; blank means now with no scheduled end.</p></div>
        {workspace.consignment_agreements.length ? (
          <form action={configureFinanceTermsAction} className="inventory-command-form inventory-receipt-form">
            <input name="currency_code" type="hidden" value={REGISTRY_CONFIG.currency.code} />
            <input name="reason" type="hidden" value="Commission terms set through guided consignment finance." />
            <label className="field"><span>Consignment agreement</span><select defaultValue="" name="agreement_id" required><option disabled value="">Choose an agreement</option>{workspace.consignment_agreements.map((item) => <option key={item.id} value={item.id}>{item.label}</option>)}</select></label>
            <label className="field"><span>Business commission</span><div className="input-suffix"><input min="0" max="100" name="commission_percent" required step="0.01" type="number" /><span>%</span></div></label>
            <details className="advanced-fields staff-field-wide"><summary>Optional start and end dates</summary><div><label className="field"><span>Starts</span><input name="effective_from" type="datetime-local" /></label><label className="field"><span>Ends</span><input name="effective_until" type="datetime-local" /></label></div></details>
            <button className="button button-primary">Save commission</button>
          </form>
        ) : (
          <div className="empty-state compact-empty-state"><h3>Create a consignment agreement first.</h3><p>Commission terms attach to the agreement that governs custody.</p><Link className="button button-primary" href="/staff/consignments">Create agreement</Link></div>
        )}
      </section>

      <section className="inventory-section">
        <div className="inventory-section-heading"><div><p className="eyebrow">Accepted sales reports</p><h2>Create settlement</h2></div><p>Enter the actual sale price. The database applies the terms in force when the report was submitted.</p></div>
        <div className="inventory-command-grid">
          {workspace.settlement_candidates.map((candidate) => (
            <form action={createSettlementAction} className="inventory-command-form" key={candidate.report_id}>
              <h3>{candidate.report_reference}</h3><p>{candidate.agreement_reference} · {candidate.quantity_sold} sold</p>
              <input name="report_id" type="hidden" value={candidate.report_id} />
              <input name="reason" type="hidden" value="Accepted consignment report settled through finance workspace." />
              <label className="field"><span>Actual sale price per unit</span><div className="input-suffix"><input min="0" name="unit_sale_price" required type="number" /><span>{REGISTRY_CONFIG.currency.code}</span></div></label>
              <button className="button button-primary">Freeze settlement</button>
            </form>
          ))}
        </div>
        {!workspace.settlement_candidates.length && <p className="empty-state">No accepted sales report is waiting for settlement.</p>}
      </section>

      <section className="inventory-section">
        <div className="inventory-section-heading"><div><p className="eyebrow">Financial register</p><h2>Settlements</h2></div></div>
        <div className="inventory-reservation-list">
          {workspace.settlements.map((settlement) => (
            <article className="inventory-reservation-card" key={settlement.id}>
              <header><h3>{settlement.reference}</h3><strong>{settlement.status}</strong></header>
              <dl className="order-facts"><div><dt>Gross</dt><dd>{settlement.gross} {settlement.currency}</dd></div><div><dt>Commission</dt><dd>{settlement.commission} {settlement.currency}</dd></div><div><dt>Owner amount</dt><dd>{settlement.owner_amount} {settlement.currency}</dd></div></dl>
              {settlement.status === "pending" && <form action={markSettlementPaidAction} className="inventory-command-form"><input name="settlement_id" type="hidden" value={settlement.id} /><input name="expected_version" type="hidden" value={settlement.version} /><input name="reason" type="hidden" value="Settlement payment recorded through finance workspace." /><label className="field"><span>Payment reference or evidence</span><input maxLength={200} name="payment_reference" required /></label><button className="button button-primary">Record paid</button></form>}
            </article>
          ))}
        </div>
        {!workspace.settlements.length && <p className="empty-state">No financial settlement has been created.</p>}
      </section>
    </main>
  );
}
