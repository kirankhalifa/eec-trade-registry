import Link from "next/link";
import { notFound } from "next/navigation";
import { z } from "zod";

import { cancelDealerOrderAction } from "@/app/dealer/orders/actions";
import { DealerAccessDenied } from "@/components/dealer-access-denied";
import { OrderNotice } from "@/components/order-notice";
import { requireDealerSession } from "@/lib/dealer-auth";
import { getDefaultLocale } from "@/lib/env";
import { getDealerOrder } from "@/lib/orders";

interface DealerOrderDetailProps {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ error?: string; notice?: string }>;
}

export default async function DealerOrderDetail({
  params,
  searchParams,
}: DealerOrderDetailProps) {
  const [{ id }, parameters] = await Promise.all([params, searchParams]);
  if (!z.string().uuid().safeParse(id).success) notFound();

  const { client } = await requireDealerSession();
  const result = await getDealerOrder(client, id);
  if (!result.ok && result.code === "access_denied") {
    return (
      <main className="dealer-main">
        <DealerAccessDenied />
      </main>
    );
  }
  if (!result.ok) {
    return <main className="dealer-main"><section className="notice-panel"><h1>Order unavailable</h1></section></main>;
  }
  if (!result.data) notFound();
  const order = result.data;
  const locale = getDefaultLocale();

  return (
    <main className="staff-editor-main dealer-main">
      <Link className="back-link" href="/dealer/orders">← Back to orders</Link>
      <header className="staff-editor-header">
        <p className="eyebrow">Dealer requisition · {order.status.replaceAll("_", " ")}</p>
        <h1>{order.public_reference}</h1>
        <p>{order.ordering_party_name} · submitted {new Date(order.submitted_at).toLocaleString(locale)}</p>
      </header>

      <OrderNotice error={parameters.error} notice={parameters.notice} />

      <section className="order-detail-lines">
        {order.lines.map((line) => (
          <article className="order-line-card" key={line.id}>
            <header>
              <div>
                <span className={`order-status order-status-${line.status}`}>
                  {line.status.replaceAll("_", " ")}
                </span>
                <h2>{line.item_name}</h2>
                <p>{line.item_code} · {line.control_profile_code}</p>
              </div>
              <strong>{line.quantity_requested} {line.unit_code}</strong>
            </header>
            <dl className="order-facts">
              <div><dt>Approved</dt><dd>{line.quantity_approved ?? "Pending"}</dd></div>
              <div><dt>Price</dt><dd>{line.unit_price_minor === null ? "Pending" : `${line.unit_price_minor} ${order.currency_code}`}</dd></div>
              <div><dt>Stock</dt><dd>{line.status.includes("awaiting_stock") ? "Awaiting stock" : "Not reserved at submission"}</dd></div>
            </dl>
          </article>
        ))}
      </section>

      {!['cancelled', 'denied', 'fulfilled'].includes(order.status) && (
        <section className="staff-danger-zone">
          <div>
            <p className="eyebrow">Unfulfilled order</p>
            <h2>Cancel requisition</h2>
            <p>Cancellation preserves the order and line history. Fulfilled quantities cannot be cancelled through this path.</p>
          </div>
          <form action={cancelDealerOrderAction} className="staff-status-form">
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
