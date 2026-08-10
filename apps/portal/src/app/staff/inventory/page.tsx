import Link from "next/link";

import { signOutAction } from "@/app/staff/actions";
import {
  createReservationAction,
  expireReservationAction,
  extendReservationAction,
  postInventoryReceiptAction,
  releaseReservationAction,
  reverseInventoryTransactionAction,
} from "@/app/staff/inventory/actions";
import { InventoryNotice } from "@/components/inventory-notice";
import { StaffAccessDenied } from "@/components/staff-access-denied";
import { getDefaultLocale } from "@/lib/env";
import { getStaffInventoryWorkspace } from "@/lib/inventory";
import { requireStaffSession } from "@/lib/staff-auth";

interface StaffInventoryPageProps {
  searchParams: Promise<{ error?: string; notice?: string }>;
}

function quantity(value: number) {
  return new Intl.NumberFormat(undefined, { maximumFractionDigits: 3 }).format(value);
}

export default async function StaffInventoryPage({ searchParams }: StaffInventoryPageProps) {
  const parameters = await searchParams;
  const { client } = await requireStaffSession();
  const result = await getStaffInventoryWorkspace(client);
  if (!result.ok && result.code === "access_denied") {
    return <main className="staff-main"><StaffAccessDenied /></main>;
  }
  if (!result.ok) {
    return (
      <main className="staff-main">
        <section className="notice-panel">
          <h1>Inventory desk unavailable</h1>
          <p>No fallback balance was used and no authoritative data was changed.</p>
        </section>
      </main>
    );
  }

  const workspace = result.data;
  const locale = getDefaultLocale();
  const totals = workspace.positions.reduce(
    (sum, position) => ({
      available: sum.available + position.available,
      onHand: sum.onHand + position.on_hand,
      reserved: sum.reserved + position.reserved,
    }),
    { available: 0, onHand: 0, reserved: 0 },
  );
  const availablePositions = workspace.positions.filter(
    (position) => position.stock_state === "available" && position.available > 0,
  );
  const fungibleItems = workspace.items.filter((item) => item.inventory_mode === "fungible");

  return (
    <main className="staff-main">
      <header className="staff-page-header">
        <div>
          <p className="eyebrow">Authenticated staff · warehouse ledger</p>
          <h1>Inventory and reservations</h1>
          <p>On-hand stock is derived from immutable balanced entries. Reservations are separate 48-hour claims and never overwrite a balance.</p>
        </div>
        <div className="staff-button-row">
          <Link className="button button-primary" href="/staff/configuration">Quick add</Link>
          <Link className="button button-secondary" href="/staff/orders">Order desk</Link>
          <Link className="button button-secondary" href="/staff/economy">Economy desk</Link>
          <Link className="button button-secondary" href="/staff/fulfillment">Fulfillment</Link>
          <Link className="button button-secondary" href="/staff/transfers">Transfers</Link>
          <Link className="button button-secondary" href="/staff/assets">Serialized assets</Link>
          <Link className="button button-secondary" href="/staff/consignments">Consignments</Link>
          <Link className="button button-secondary" href="/staff">Catalogue desk</Link>
          <form action={signOutAction}><button className="button button-primary" type="submit">Sign out</button></form>
        </div>
      </header>

      <InventoryNotice error={parameters.error} notice={parameters.notice} />

      <section className="inventory-summary" aria-label="Inventory totals">
        <article><span>On hand</span><strong>{quantity(totals.onHand)}</strong></article>
        <article><span>Reserved</span><strong>{quantity(totals.reserved)}</strong></article>
        <article><span>Available</span><strong>{quantity(totals.available)}</strong></article>
        <article><span>Active/elapsed claims</span><strong>{workspace.reservations.filter((entry) => entry.status === "active").length}</strong></article>
      </section>

      <div className="inventory-command-grid">
        <section className="staff-form inventory-command-card">
          <div><p className="eyebrow">Immutable receipt</p><h2>Receive fungible stock</h2><p>Use only for goods whose supply policy permits generic receipts. Player-sourced keystone materials must use the economy desk.</p></div>
          <form action={postInventoryReceiptAction} className="inventory-command-form">
            <label className="field"><span>Warehouse location</span><select name="stock_location_id" required>{workspace.warehouses.flatMap((warehouse) => warehouse.locations.map((location) => <option key={location.id} value={location.id}>{warehouse.display_name} · {location.display_name}</option>))}</select></label>
            <label className="field"><span>Fungible item</span><select name="item_id" required>{fungibleItems.map((item) => <option key={item.id} value={item.id}>{item.item_code} · {item.display_name} ({item.unit_code})</option>)}</select></label>
            <label className="field"><span>Quantity</span><input min="0.001" name="quantity" required step="0.001" type="number" /></label>
            <label className="field"><span>Source or manifest reference</span><input maxLength={200} name="source_reference" required /></label>
            <label className="field"><span>Audit reason</span><textarea maxLength={500} name="reason" required rows={3} /></label>
            <button className="button button-primary" disabled={fungibleItems.length === 0 || workspace.warehouses.length === 0} type="submit">Post receipt</button>
          </form>
        </section>

        <section className="staff-form inventory-command-card">
          <div><p className="eyebrow">Atomic stock claim</p><h2>Reserve approved demand</h2><p>The database rechecks account availability and approved remaining quantity.</p></div>
          <form action={createReservationAction} className="inventory-command-form">
            <label className="field"><span>Approved order line</span><select name="order_line_id" required>{workspace.order_lines.map((line) => <option key={line.id} value={line.id}>{line.order_reference} · line {line.line_number} · {line.item_code} · {quantity(line.quantity_approved - line.quantity_fulfilled - line.quantity_reserved)} remaining</option>)}</select></label>
            <label className="field"><span>Available inventory account</span><select name="inventory_account_id" required>{availablePositions.map((position) => <option key={position.account_id} value={position.account_id}>{position.item_code} · {position.warehouse_name}/{position.location_name} · {quantity(position.available)} available</option>)}</select></label>
            <label className="field"><span>Quantity</span><input min="0.001" name="quantity" required step="0.001" type="number" /></label>
            <label className="field"><span>Audit reason</span><textarea maxLength={500} name="reason" required rows={3} /></label>
            <button className="button button-primary" disabled={workspace.order_lines.length === 0 || availablePositions.length === 0} type="submit">Create 48-hour reservation</button>
          </form>
        </section>
      </div>

      <section className="inventory-section">
        <div className="inventory-section-heading"><div><p className="eyebrow">Derived projection</p><h2>Stock positions</h2></div><p>No editable current-stock field exists.</p></div>
        <div className="inventory-table-wrap"><table className="inventory-table"><thead><tr><th>Warehouse / location</th><th>Item</th><th>State</th><th>On hand</th><th>Reserved</th><th>Available</th></tr></thead><tbody>{workspace.positions.map((position) => <tr key={position.account_id}><td>{position.warehouse_name}<small>{position.location_name}</small></td><td>{position.item_code}<small>{position.item_name}</small></td><td>{position.stock_state.replaceAll("_", " ")}</td><td>{quantity(position.on_hand)} {position.unit_code}</td><td>{quantity(position.reserved)}</td><td><strong>{quantity(position.available)}</strong></td></tr>)}</tbody></table></div>
        {workspace.positions.length === 0 && <p className="empty-state">No stock has been posted. Seed configuration does not invent an opening balance.</p>}
      </section>

      <section className="inventory-section">
        <div className="inventory-section-heading"><div><p className="eyebrow">Time-bounded claims</p><h2>Reservations</h2></div><p>Elapsed claims stop reducing availability and must be finalized explicitly.</p></div>
        <div className="inventory-reservation-list">
          {workspace.reservations.map((reservation) => {
            const active = reservation.status === "active";
            const elapsed = reservation.effective_status === "elapsed";
            return <article className="inventory-reservation-card" key={reservation.id}>
              <header><div><span className={`order-status order-status-${reservation.effective_status}`}>{reservation.effective_status}</span><h3>{reservation.public_reference}</h3></div><strong>{quantity(reservation.quantity)}</strong></header>
              <p>{reservation.order_reference} · line {reservation.line_number} · {reservation.item_code}</p>
              <dl className="order-facts"><div><dt>Location</dt><dd>{reservation.warehouse_name} / {reservation.location_name}</dd></div><div><dt>Expires</dt><dd>{new Date(reservation.expires_at).toLocaleString(locale)}</dd></div><div><dt>Version</dt><dd>{reservation.version}</dd></div></dl>
              {active && <div className="inventory-reservation-actions">
                {!elapsed && <form action={extendReservationAction}><input name="reservation_id" type="hidden" value={reservation.id} /><input name="expected_version" type="hidden" value={reservation.version} /><label className="field"><span>New expiration (UTC)</span><input name="expires_at" required type="datetime-local" /></label><label className="field"><span>Reason</span><input maxLength={500} name="reason" required /></label><button className="button button-secondary" type="submit">Extend</button></form>}
                <form action={elapsed ? expireReservationAction : releaseReservationAction}><input name="reservation_id" type="hidden" value={reservation.id} /><input name="expected_version" type="hidden" value={reservation.version} /><label className="field"><span>Reason</span><input maxLength={500} name="reason" required /></label><button className="button button-secondary" type="submit">{elapsed ? "Finalize expiry" : "Release"}</button></form>
              </div>}
            </article>;
          })}
        </div>
        {workspace.reservations.length === 0 && <p className="empty-state">No reservation history yet.</p>}
      </section>

      <section className="inventory-section">
        <div className="inventory-section-heading"><div><p className="eyebrow">Posted evidence</p><h2>Recent ledger transactions</h2></div><p>Corrections add a linked reversal; originals cannot be edited.</p></div>
        <div className="inventory-transaction-list">{workspace.transactions.map((transaction) => <article className="inventory-transaction-card" key={transaction.id}><div><span className="order-status">{transaction.transaction_type}</span><h3>{transaction.source_reference}</h3><p>{transaction.item_code} · {quantity(transaction.quantity_delta)} · {transaction.warehouse_name}</p><small>{new Date(transaction.posted_at).toLocaleString(locale)}</small></div>{transaction.transaction_type === "receipt" && !transaction.is_reversed && <form action={reverseInventoryTransactionAction}><input name="inventory_transaction_id" type="hidden" value={transaction.id} /><label className="field"><span>Correction reason</span><input maxLength={500} name="reason" required /></label><button className="button button-secondary" type="submit">Post reversal</button></form>}</article>)}</div>
      </section>
    </main>
  );
}
