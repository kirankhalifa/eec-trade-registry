import Link from "next/link";
import { notFound } from "next/navigation";
import { z } from "zod";

import {
  cancelStaffOrderAction,
  priceOrderLineAction,
  reviewOrderLineAction,
} from "@/app/staff/orders/actions";
import { OrderNotice } from "@/components/order-notice";
import { StaffAccessDenied } from "@/components/staff-access-denied";
import { getDefaultLocale } from "@/lib/env";
import { getStaffOrder } from "@/lib/orders";
import { requireStaffSession } from "@/lib/staff-auth";

interface StaffOrderDetailProps {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ error?: string; notice?: string }>;
}

export default async function StaffOrderDetail({ params, searchParams }: StaffOrderDetailProps) {
  const [{ id }, parameters] = await Promise.all([params, searchParams]);
  if (!z.guid().safeParse(id).success) notFound();
  const { client } = await requireStaffSession();
  const result = await getStaffOrder(client, id);
  if (!result.ok && result.code === "access_denied") {
    return <main className="staff-editor-main staff-main"><StaffAccessDenied /></main>;
  }
  if (!result.ok) {
    return <main className="staff-editor-main staff-main"><section className="notice-panel"><h1>Order unavailable</h1></section></main>;
  }
  if (!result.data) notFound();
  const order = result.data;
  const locale = getDefaultLocale();
  const terminal = ["cancelled", "denied", "fulfilled"].includes(order.status);

  return (
    <main className="staff-editor-main staff-main">
      <Link className="back-link" href="/staff/orders">← Back to order queue</Link>
      <header className="staff-editor-header">
        <p className="eyebrow">Order desk · {order.status.replaceAll("_", " ")}</p>
        <h1>{order.public_reference}</h1>
        <p>{order.ordering_party_name} · {order.dealer_reference} · submitted {new Date(order.submitted_at).toLocaleString(locale)}</p>
      </header>

      <OrderNotice error={parameters.error} notice={parameters.notice} />

      <section className="staff-readonly-grid">
        <div><span>Fulfillment</span><strong>{order.fulfillment_mode}</strong></div>
        <div><span>License</span><strong>{order.license_reference ?? "Not attached"}</strong></div>
        <div><span>Version</span><strong>{order.version}</strong></div>
      </section>

      <p className="order-policy-banner">No stock was checked or reserved at submission. “Awaiting stock” records approved demand without posting negative inventory.</p>

      <section className="order-detail-lines">
        {order.lines.map((line) => (
          <article className="order-line-card" key={line.id}>
            <header>
              <div>
                <span className={`order-status order-status-${line.status}`}>{line.status.replaceAll("_", " ")}</span>
                <h2>{line.item_name}</h2>
                <p>{line.item_code} · {line.control_profile_code}</p>
              </div>
              <strong>{line.quantity_requested} {line.unit_code}</strong>
            </header>
            <dl className="order-facts">
              <div><dt>Approved</dt><dd>{line.quantity_approved ?? "Pending"}</dd></div>
              <div><dt>Price</dt><dd>{line.unit_price_minor === null ? "Pending" : `${line.unit_price_minor} ${order.currency_code}`}</dd></div>
              <div><dt>Controls</dt><dd>{line.requires_serial_tracking ? "Unique / serialized" : line.requires_transaction_approval ? "Transaction approval" : line.requires_staff_review ? "Restricted review" : "Ordinary"}</dd></div>
            </dl>

            {!terminal && (
              <div className="order-line-actions">
                <form action={reviewOrderLineAction} className="staff-form">
                  <input name="order_id" type="hidden" value={order.id} />
                  <input name="order_line_id" type="hidden" value={line.id} />
                  <input name="expected_order_version" type="hidden" value={order.version} />
                  <div className="staff-form-grid">
                    <label className="field"><span>Decision</span><select name="decision"><option value="approve">Approve</option><option value="awaiting_stock">Approve awaiting stock</option><option value="deny">Deny</option></select></label>
                    <label className="field"><span>Approved quantity</span><input max={line.quantity_requested} min="0.001" name="approved_quantity" step="0.001" type="number" /></label>
                    <label className="field"><span>Unit price ({order.currency_code}, optional)</span><input min="0" name="unit_price_minor" step="1" type="number" /></label>
                    <label className="field"><span>Decision reason</span><input maxLength={500} minLength={1} name="reason" required /></label>
                  </div>
                  <button className="button button-primary" type="submit">Record line decision</button>
                </form>

                <form action={priceOrderLineAction} className="staff-inline-action">
                  <input name="order_id" type="hidden" value={order.id} />
                  <input name="order_line_id" type="hidden" value={line.id} />
                  <input name="expected_order_version" type="hidden" value={order.version} />
                  <label className="field"><span>Edit price; blank returns to pending</span><input defaultValue={line.unit_price_minor ?? ""} min="0" name="unit_price_minor" step="1" type="number" /></label>
                  <label className="field"><span>Price change reason</span><input maxLength={500} minLength={1} name="reason" required /></label>
                  <button className="button button-secondary" type="submit">Save price</button>
                </form>
              </div>
            )}
          </article>
        ))}
      </section>

      {!terminal && (
        <section className="staff-danger-zone">
          <div><p className="eyebrow">Unfulfilled order</p><h2>Cancel order</h2><p>Cancellation preserves all submitted and reviewed line history.</p></div>
          <form action={cancelStaffOrderAction} className="staff-status-form">
            <input name="order_id" type="hidden" value={order.id} />
            <input name="expected_version" type="hidden" value={order.version} />
            <label className="field"><span>Cancellation reason</span><textarea maxLength={500} minLength={1} name="reason" required rows={3} /></label>
            <button className="button button-secondary" type="submit">Cancel order</button>
          </form>
        </section>
      )}
    </main>
  );
}
