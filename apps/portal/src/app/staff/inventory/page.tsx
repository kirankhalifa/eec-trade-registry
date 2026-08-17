import Link from "next/link";

import {
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
  const fungibleItems = workspace.items.filter((item) => item.inventory_mode === "fungible");
  const stockLocations = workspace.warehouses.flatMap((warehouse) =>
    warehouse.locations.map((location) => ({
      ...location,
      warehouseName: warehouse.display_name,
    })),
  );

  return (
    <main className="staff-main">
      <header className="staff-page-header">
        <div>
          <p className="eyebrow">Warehouse stock</p>
          <h1>Stock</h1>
          <p>Receive ordinary goods and see what is physically available. Orders hold their own stock automatically from the order page.</p>
        </div>
        <div className="staff-button-row">
          <Link className="button button-primary" href="/staff/buy">Buy player materials</Link>
        </div>
      </header>

      <InventoryNotice error={parameters.error} notice={parameters.notice} />

      <div className="inventory-command-grid stock-primary-grid">
        <section className="staff-form inventory-command-card">
          <div><p className="eyebrow">Quick stock intake</p><h2>Receive ordinary stock</h2><p>Choose the item and quantity. Player-sourced materials use Buy materials so the supplier and guaranteed payment are recorded.</p></div>
          {fungibleItems.length > 0 && stockLocations.length > 0 ? <form action={postInventoryReceiptAction} className="inventory-command-form">
            {stockLocations.length === 1 ? <><input name="stock_location_id" type="hidden" value={stockLocations[0].id} /><p className="derived-choice"><span>Receive into</span><strong>{stockLocations[0].warehouseName} · {stockLocations[0].display_name}</strong></p></> : <label className="field"><span>Receive into</span><select defaultValue="" name="stock_location_id" required><option disabled value="">Choose a location</option>{stockLocations.map((location) => <option key={location.id} value={location.id}>{location.warehouseName} · {location.display_name}</option>)}</select></label>}
            <label className="field"><span>Item received</span><select defaultValue="" name="item_id" required><option disabled value="">Choose an item</option>{fungibleItems.map((item) => <option key={item.id} value={item.id}>{item.item_code} · {item.display_name} ({item.unit_code})</option>)}</select></label>
            <label className="field"><span>Quantity</span><input min="0.001" name="quantity" required step="0.001" type="number" /></label>
            <input name="source_reference" type="hidden" value="Routine staff stock intake" />
            <input name="reason" type="hidden" value="Ordinary stock received and counted by staff." />
            <button className="button button-primary" type="submit">Add to stock</button>
          </form> : <div className="empty-state"><p>No items currently permit a generic warehouse receipt.</p><Link href="/staff/economy">Receive player-sourced materials through the economy desk</Link></div>}
        </section>
      </div>

      <section className="inventory-section">
        <div className="inventory-section-heading"><div><p className="eyebrow">Current stock</p><h2>What is available?</h2></div><p>Held stock is already removed from “Available.”</p></div>
        <div className="inventory-table-wrap"><table className="inventory-table"><thead><tr><th>Warehouse / location</th><th>Item</th><th>State</th><th>On hand</th><th>Reserved</th><th>Available</th></tr></thead><tbody>{workspace.positions.map((position) => <tr key={position.account_id}><td>{position.warehouse_name}<small>{position.location_name}</small></td><td>{position.item_code}<small>{position.item_name}</small></td><td>{position.stock_state.replaceAll("_", " ")}</td><td>{quantity(position.on_hand)} {position.unit_code}</td><td>{quantity(position.reserved)}</td><td><strong>{quantity(position.available)}</strong></td></tr>)}</tbody></table></div>
        {workspace.positions.length === 0 && <p className="empty-state">No stock has been posted. Seed configuration does not invent an opening balance.</p>}
      </section>

      <details className="staff-tools-panel inline-tools-panel stock-tools-panel"><summary><span><span><strong>Stock history and advanced controls</strong><small>Expired holds, reversals, and immutable ledger evidence</small></span></span><span>Open</span></summary><div className="staff-tools-content">
      <section className="inventory-section embedded-inventory-section">
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

      <section className="inventory-section embedded-inventory-section">
        <div className="inventory-section-heading"><div><p className="eyebrow">Posted evidence</p><h2>Recent ledger transactions</h2></div><p>Corrections add a linked reversal; originals cannot be edited.</p></div>
        <div className="inventory-transaction-list">{workspace.transactions.map((transaction) => <article className="inventory-transaction-card" key={transaction.id}><div><span className="order-status">{transaction.transaction_type}</span><h3>{transaction.source_reference}</h3><p>{transaction.item_code} · {quantity(transaction.quantity_delta)} · {transaction.warehouse_name}</p><small>{new Date(transaction.posted_at).toLocaleString(locale)}</small></div>{transaction.transaction_type === "receipt" && !transaction.is_reversed && <form action={reverseInventoryTransactionAction}><input name="inventory_transaction_id" type="hidden" value={transaction.id} /><label className="field"><span>Correction reason</span><input maxLength={500} name="reason" required /></label><button className="button button-secondary" type="submit">Post reversal</button></form>}</article>)}</div>
      </section>
      </div></details>
    </main>
  );
}
