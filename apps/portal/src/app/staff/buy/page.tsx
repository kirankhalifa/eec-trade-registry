import Link from "next/link";

import { settleDeliveryAction } from "@/app/staff/economy/actions";
import { EconomyNotice } from "@/components/economy-notice";
import { GuidedMaterialPurchaseForm } from "@/components/guided-material-purchase-form";
import { StaffAccessDenied } from "@/components/staff-access-denied";
import { getStaffEconomyWorkspace } from "@/lib/economy";
import { requireStaffSession } from "@/lib/staff-auth";

interface PageProps { searchParams: Promise<{ error?: string; notice?: string }> }

export default async function BuyMaterialsPage({ searchParams }: PageProps) {
  const parameters = await searchParams;
  const { client } = await requireStaffSession();
  const result = await getStaffEconomyWorkspace(client);
  if (!result.ok && result.code === "access_denied") return <main className="staff-main"><StaffAccessDenied /></main>;
  if (!result.ok) return <main className="staff-main"><section className="notice-panel"><h1>Material purchasing unavailable</h1><p>The authoritative registry could not be reached. No fallback rate or stock was used.</p></section></main>;

  const pending = result.data.deliveries.filter((delivery) => delivery.settlement_status === "pending" && !delivery.is_reversed).slice(0, 5);
  return (
    <main className="staff-main simple-task-main">
      <header className="staff-page-header"><div><p className="eyebrow">Guaranteed material purchasing</p><h1>Buy materials</h1><p>Choose the supplier, material, and quantity. The approved rate and stock receipt are handled automatically.</p></div><Link className="button button-secondary" href="/staff/dashboard">Back to Today</Link></header>
      <EconomyNotice error={parameters.error} notice={parameters.notice} />
      <GuidedMaterialPurchaseForm workspace={result.data} />

      {pending.length > 0 && <details className="staff-tools-panel inline-tools-panel"><summary><span><span><strong>Payments still to record</strong><small>{pending.length} recent purchase{pending.length === 1 ? "" : "s"} are waiting for a voucher or payment reference</small></span></span><span>Open</span></summary><div className="staff-tools-content"><div className="inventory-transaction-list">{pending.map((delivery) => <article className="inventory-transaction-card" key={delivery.id}><div><h3>{delivery.supplier_name} · {delivery.item_name}</h3><p>{delivery.quantity} {delivery.unit_code} · {delivery.total_amount_minor} {delivery.currency_code}</p><small>{delivery.public_reference}</small></div><form action={settleDeliveryAction}><input name="delivery_id" type="hidden" value={delivery.id} /><input name="expected_version" type="hidden" value={delivery.version} /><input name="reason" type="hidden" value="External supplier payment recorded." /><label className="field"><span>Payment or voucher reference</span><input maxLength={200} name="settlement_reference" required /></label><button className="button button-secondary">Mark paid</button></form></article>)}</div></div></details>}
    </main>
  );
}
