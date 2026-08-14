import Link from "next/link";

import { settleDeliveryAction } from "@/app/staff/economy/actions";
import { EconomyNotice } from "@/components/economy-notice";
import { StaffAccessDenied } from "@/components/staff-access-denied";
import { getStaffEconomyWorkspace } from "@/lib/economy";
import { getDefaultLocale } from "@/lib/env";
import { requireStaffSession } from "@/lib/staff-auth";

interface PageProps { searchParams: Promise<{ error?: string; notice?: string }> }
const number = (value: number) => new Intl.NumberFormat(undefined, { maximumFractionDigits: 3 }).format(value);
const money = (value: number, code = "SEP") => `${new Intl.NumberFormat().format(value)} ${code}`;

export default async function EconomyPage({ searchParams }: PageProps) {
  const parameters = await searchParams;
  const { client } = await requireStaffSession();
  const result = await getStaffEconomyWorkspace(client);
  if (!result.ok && result.code === "access_denied") return <main className="staff-main"><StaffAccessDenied /></main>;
  if (!result.ok) return <main className="staff-main"><section className="notice-panel"><h1>Economic desk unavailable</h1><p>No fallback figures were used and no authoritative records changed.</p></section></main>;

  const workspace = result.data;
  const locale = getDefaultLocale();
  const materials = workspace.positions.filter((position) =>
    position.procurement_enabled || position.supply_mode === "player_sourced_reserve",
  );
  const allUnconfigured = materials.length > 0 && materials.every((position) => position.reserve_state === "unconfigured");
  const totals = materials.reduce((sum, position) => ({
    backordered: sum.backordered + position.backordered,
    committed: sum.committed + position.committed_7d_minor,
    onHand: sum.onHand + position.on_hand,
    paid: sum.paid + position.paid_7d_minor,
  }), { backordered: 0, committed: 0, onHand: 0, paid: 0 });

  return <main className="staff-main">
    <header className="staff-page-header"><div><p className="eyebrow">Economic operations</p><h1>Reserve economy</h1><p>See which materials need attention, then open that material to set policy, publish its floor, receive supply, or record payment.</p></div><div className="staff-button-row"><Link className="button button-secondary" href="/staff/inventory">View inventory</Link></div></header>
    <EconomyNotice error={parameters.error} notice={parameters.notice} />

    {allUnconfigured && <section className="setup-callout"><div><p className="eyebrow">Setup required</p><h2>Reserve targets have not been set</h2><p>Choose the desired safety levels for each player-sourced material. Ledger quantities remain untouched.</p></div><Link className="button button-primary" href={`/staff/materials/${encodeURIComponent(materials[0].item_code)}`}>Set the first material</Link></section>}

    <section className="policy-principle"><strong>Thresholds are policy.</strong><span>On-hand, reserved, available, purchasing, and payment figures are always derived from the ledger.</span></section>

    <section className="inventory-summary" aria-label="Economy totals">
      <article><span>Physical reserve</span><strong>{number(totals.onHand)}</strong></article>
      <article><span>Approved unmet demand</span><strong>{number(totals.backordered)}</strong></article>
      <article><span>7-day purchase obligation</span><strong>{money(totals.committed)}</strong></article>
      <article><span>7-day recorded payment</span><strong>{money(totals.paid)}</strong></article>
    </section>

    <section className="inventory-section"><div className="inventory-section-heading"><div><p className="eyebrow">Action queue</p><h2>Procured materials</h2></div><p>Open a material to work on it.</p></div>
      <div className="inventory-table-wrap"><table className="inventory-table"><thead><tr><th>Material</th><th>State</th><th>Available / target</th><th>Unmet demand</th><th>7-day purchasing</th><th>Next action</th></tr></thead><tbody>{materials.map((position) => <tr key={position.item_id}><td><Link href={`/staff/materials/${encodeURIComponent(position.item_code)}`}><strong>{position.item_name}</strong></Link><small>{position.item_code}</small></td><td><span className={`order-status order-status-${position.reserve_state}`}>{position.reserve_state.replaceAll("_", " ")}</span></td><td>{number(position.available)} {position.unit_code}<small>{position.target_level === null ? "Target not set" : `target ${number(position.target_level)}`}</small></td><td>{number(position.backordered)}</td><td>{number(position.procured_7d)} units<small>{money(position.committed_7d_minor)} committed</small></td><td><Link className="text-link" href={`/staff/materials/${encodeURIComponent(position.item_code)}`}>{position.reserve_state === "unconfigured" ? "Set policy" : "Open material"} →</Link></td></tr>)}</tbody></table></div>
      {!materials.length && <p className="empty-state">No items are configured for procurement. Configure a catalogue item before publishing a purchase floor.</p>}
    </section>

    <section className="inventory-section"><div className="inventory-section-heading"><div><p className="eyebrow">Current guarantee</p><h2>Purchase offers</h2></div><p>An offer promises a rate; it does not create stock.</p></div><div className="inventory-table-wrap"><table className="inventory-table"><thead><tr><th>Item</th><th>Rate</th><th>Minimum / review</th><th>Effective period</th><th>Status</th></tr></thead><tbody>{workspace.offers.map((offer) => <tr key={offer.id}><td><Link href={`/staff/materials/${encodeURIComponent(offer.item_code)}`}>{offer.item_name}</Link><small>{offer.item_code}</small></td><td>{money(offer.amount_minor, offer.currency_code)}<small>per {offer.unit_code}</small></td><td>{number(offer.minimum_quantity)} / {offer.staff_review_quantity === null ? "not set" : number(offer.staff_review_quantity)}</td><td>{new Date(offer.effective_from).toLocaleString(locale)}<small>{offer.effective_until ? `to ${new Date(offer.effective_until).toLocaleString(locale)}` : "No scheduled end"}</small></td><td>{offer.is_current ? "Current" : offer.status}</td></tr>)}</tbody></table></div>{!workspace.offers.length && <p className="empty-state">No purchasing rate has been approved yet. Open a material to publish its first floor.</p>}</section>

    <section className="inventory-section"><div className="inventory-section-heading"><div><p className="eyebrow">Accepted supply</p><h2>Deliveries awaiting settlement</h2></div><p>“Paid” means staff recorded an external payment reference; this is not a treasury ledger.</p></div><div className="inventory-transaction-list">{workspace.deliveries.map((delivery) => <article className="inventory-transaction-card" key={delivery.id}><div><span className="order-status">{delivery.is_reversed ? "reversed" : delivery.settlement_status}</span><h3>{delivery.public_reference} · {delivery.supplier_name}</h3><p>{delivery.item_code} · {number(delivery.quantity)} {delivery.unit_code} · {money(delivery.total_amount_minor, delivery.currency_code)}</p><small>{delivery.warehouse_name} / {delivery.location_name} · {new Date(delivery.received_at).toLocaleString(locale)}</small>{delivery.settlement_reference && <small>Payment: {delivery.settlement_reference}</small>}</div>{delivery.settlement_status === "pending" && !delivery.is_reversed && <form action={settleDeliveryAction}><input name="delivery_id" type="hidden" value={delivery.id}/><input name="expected_version" type="hidden" value={delivery.version}/><label className="field"><span>Payment or voucher reference</span><input maxLength={200} name="settlement_reference" required/></label><label className="field"><span>Reason</span><input maxLength={500} name="reason" required/></label><button className="button button-secondary">Record paid</button></form>}</article>)}</div>{!workspace.deliveries.length && <p className="empty-state">No player-sourced deliveries have been accepted.</p>}</section>
  </main>;
}
