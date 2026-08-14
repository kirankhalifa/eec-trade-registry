import Link from "next/link";

import { OrderNotice } from "@/components/order-notice";
import { StaffAccessDenied } from "@/components/staff-access-denied";
import { getDefaultLocale } from "@/lib/env";
import { getStaffOrders } from "@/lib/orders";
import { requireStaffSession } from "@/lib/staff-auth";

interface StaffOrdersPageProps {
  searchParams: Promise<{ error?: string; notice?: string; q?: string }>;
}

export default async function StaffOrdersPage({ searchParams }: StaffOrdersPageProps) {
  const parameters = await searchParams;
  const search = parameters.q?.trim().slice(0, 100) || undefined;
  const { client } = await requireStaffSession();
  const result = await getStaffOrders(client, search);
  if (!result.ok && result.code === "access_denied") {
    return <main className="staff-main"><StaffAccessDenied /></main>;
  }
  if (!result.ok) {
    return <main className="staff-main"><section className="notice-panel"><h1>Order queue unavailable</h1><p>No authoritative data was changed.</p></section></main>;
  }

  const locale = getDefaultLocale();
  return (
    <main className="staff-main">
      <header className="staff-page-header">
        <div>
          <p className="eyebrow">Authenticated staff · order desk</p>
          <h1>Wholesale order queue</h1>
          <p>Review dealer requisitions, record nullable Septim prices, approve partial quantities, or place approved demand in awaiting-stock state.</p>
        </div>
        <div className="staff-button-row">
          <Link className="button button-primary" href="/staff/orders/new">Enter an order</Link>
          <Link className="button button-secondary" href="/staff/fulfillment">Open fulfillment</Link>
        </div>
      </header>

      <OrderNotice error={parameters.error} notice={parameters.notice} />

      <form className="staff-search" method="get" role="search">
        <label className="field"><span>Search order queue</span><input defaultValue={search} maxLength={100} name="q" placeholder="Order reference or dealer" type="search" /></label>
        <button className="button button-primary" type="submit">Search</button>
        {search && <Link className="button button-secondary" href="/staff/orders">Clear</Link>}
      </form>

      <div className="order-list">
        {result.data.map((order) => (
          <article className="order-card" key={order.id}>
            <header>
              <div>
                <span className={`order-status order-status-${order.status}`}>{order.status.replaceAll("_", " ")}</span>
                <h2>{order.public_reference}</h2>
                <p>{order.ordering_party_name}</p>
              </div>
              <strong>{order.lines.length} line{order.lines.length === 1 ? "" : "s"}</strong>
            </header>
            <dl className="order-facts">
              <div><dt>Submitted</dt><dd>{new Date(order.submitted_at).toLocaleString(locale)}</dd></div>
              <div><dt>Control</dt><dd>{order.lines.some((line) => line.requires_serial_tracking) ? "Unique item present" : order.lines.some((line) => line.requires_staff_review) ? "Restricted review" : "Routine review"}</dd></div>
              <div><dt>Pricing</dt><dd>{order.lines.some((line) => line.pricing_status === "pending") ? "Pending" : "Configured"}</dd></div>
            </dl>
            <Link className="button button-secondary" href={`/staff/orders/${order.id}`}>Review order</Link>
          </article>
        ))}
      </div>

      {result.data.length === 0 && <section className="empty-state"><p className="eyebrow">No orders found</p><h2>The queue is clear</h2></section>}
    </main>
  );
}
