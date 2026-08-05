import Link from "next/link";

import { signOutAction } from "@/app/staff/actions";
import {
  fulfillReservationAction,
  reverseFulfillmentAction,
} from "@/app/staff/fulfillment/actions";
import { FulfillmentNotice } from "@/components/fulfillment-notice";
import { StaffAccessDenied } from "@/components/staff-access-denied";
import { getDefaultLocale } from "@/lib/env";
import { getStaffFulfillmentWorkspace } from "@/lib/fulfillment";
import { requireStaffSession } from "@/lib/staff-auth";

interface StaffFulfillmentPageProps {
  searchParams: Promise<{ error?: string; notice?: string }>;
}

function quantity(value: number) {
  return new Intl.NumberFormat(undefined, { maximumFractionDigits: 3 }).format(value);
}

export default async function StaffFulfillmentPage({
  searchParams,
}: StaffFulfillmentPageProps) {
  const parameters = await searchParams;
  const { client } = await requireStaffSession();
  const result = await getStaffFulfillmentWorkspace(client);
  if (!result.ok && result.code === "access_denied") {
    return <main className="staff-main"><StaffAccessDenied /></main>;
  }
  if (!result.ok) {
    return (
      <main className="staff-main">
        <section className="notice-panel">
          <h1>Fulfillment desk unavailable</h1>
          <p>No fallback stock state was used and no authoritative record was changed.</p>
        </section>
      </main>
    );
  }

  const workspace = result.data;
  const locale = getDefaultLocale();
  const completed = workspace.fulfillments.filter(
    (fulfillment) => fulfillment.status === "completed",
  ).length;
  const reversed = workspace.fulfillments.length - completed;

  return (
    <main className="staff-main">
      <header className="staff-page-header">
        <div>
          <p className="eyebrow">Authenticated staff · custody release</p>
          <h1>Wholesale fulfillment</h1>
          <p>
            Complete current fungible reservations through one database transaction. The
            command consumes the claim, posts a balanced issue, advances demand, and emits
            durable evidence together.
          </p>
        </div>
        <div className="staff-button-row">
          <Link className="button button-secondary" href="/staff/inventory">Inventory desk</Link>
          <Link className="button button-secondary" href="/staff/orders">Order desk</Link>
          <form action={signOutAction}>
            <button className="button button-primary" type="submit">Sign out</button>
          </form>
        </div>
      </header>

      <FulfillmentNotice error={parameters.error} notice={parameters.notice} />

      <section className="inventory-summary" aria-label="Fulfillment totals">
        <article><span>Ready claims</span><strong>{workspace.ready_reservations.length}</strong></article>
        <article><span>Completed</span><strong>{completed}</strong></article>
        <article><span>Reversed</span><strong>{reversed}</strong></article>
        <article><span>Total evidence</span><strong>{workspace.fulfillments.length}</strong></article>
      </section>

      <section className="inventory-section">
        <div className="inventory-section-heading">
          <div><p className="eyebrow">Current authority</p><h2>Ready reservations</h2></div>
          <p>Only active, unexpired, fully authorized fungible claims appear.</p>
        </div>
        <div className="inventory-reservation-list">
          {workspace.ready_reservations.map((reservation) => (
            <article className="inventory-reservation-card" key={reservation.id}>
              <header>
                <div>
                  <span className="order-status order-status-reserved">ready</span>
                  <h3>{reservation.public_reference}</h3>
                </div>
                <strong>{quantity(reservation.quantity)} {reservation.unit_code}</strong>
              </header>
              <p>
                {reservation.order_reference} · line {reservation.line_number} · {reservation.item_code}
              </p>
              <dl className="order-facts">
                <div><dt>Dealer</dt><dd>{reservation.ordering_party_name}</dd></div>
                <div><dt>Warehouse</dt><dd>{reservation.warehouse_name} / {reservation.location_name}</dd></div>
                <div><dt>Mode</dt><dd>{reservation.fulfillment_mode}</dd></div>
                <div><dt>Expires</dt><dd>{new Date(reservation.expires_at).toLocaleString(locale)}</dd></div>
              </dl>
              <form action={fulfillReservationAction} className="inventory-command-form">
                <input name="reservation_id" type="hidden" value={reservation.id} />
                <input name="expected_version" type="hidden" value={reservation.version} />
                <label className="field">
                  <span>Completion reason / handoff evidence</span>
                  <textarea maxLength={500} name="reason" required rows={3} />
                </label>
                <button className="button button-primary" type="submit">
                  Complete fulfillment
                </button>
              </form>
            </article>
          ))}
        </div>
        {workspace.ready_reservations.length === 0 && (
          <p className="empty-state">No active reservation is ready for fulfillment.</p>
        )}
      </section>

      <section className="inventory-section">
        <div className="inventory-section-heading">
          <div><p className="eyebrow">Immutable movement trail</p><h2>Fulfillment history</h2></div>
          <p>Corrections add a linked reversal and reopen demand; they never erase the issue.</p>
        </div>
        <div className="inventory-transaction-list">
          {workspace.fulfillments.map((fulfillment) => (
            <article className="inventory-transaction-card" key={fulfillment.id}>
              <div>
                <span className={`order-status order-status-${fulfillment.status}`}>
                  {fulfillment.status}
                </span>
                <h3>{fulfillment.public_reference}</h3>
                <p>
                  {fulfillment.order_reference} · line {fulfillment.line_number} · {fulfillment.item_code}
                  {" · "}{quantity(fulfillment.quantity)} {fulfillment.unit_code}
                </p>
                <small>
                  {fulfillment.ordering_party_name} · {fulfillment.warehouse_name} · {new Date(fulfillment.completed_at).toLocaleString(locale)}
                </small>
              </div>
              {fulfillment.can_reverse && (
                <form action={reverseFulfillmentAction}>
                  <input name="fulfillment_id" type="hidden" value={fulfillment.id} />
                  <input name="expected_version" type="hidden" value={fulfillment.version} />
                  <label className="field">
                    <span>Correction reason</span>
                    <input maxLength={500} name="reason" required />
                  </label>
                  <button className="button button-secondary" type="submit">
                    Post linked reversal
                  </button>
                </form>
              )}
            </article>
          ))}
        </div>
        {workspace.fulfillments.length === 0 && (
          <p className="empty-state">No fulfillment evidence has been posted yet.</p>
        )}
      </section>
    </main>
  );
}
