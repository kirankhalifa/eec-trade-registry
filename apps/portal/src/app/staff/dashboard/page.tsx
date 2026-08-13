import Link from "next/link";
import { signOutAction } from "@/app/staff/actions";
import { StaffAccessDenied } from "@/components/staff-access-denied";
import { getCommandDashboard } from "@/lib/command-dashboard";
import { getDefaultLocale } from "@/lib/env";
import { requireStaffSession } from "@/lib/staff-auth";

export const dynamic = "force-dynamic";

const labels: Record<string, string> = {
  actions_pending: "Actions awaiting review", active_licenses: "Active licenses", asset_exceptions: "Asset exceptions",
  awaiting_stock: "Orders awaiting stock", critical_reserves: "Critical reserves", deliveries_failed: "Discord deliveries failed",
  direct_this_week: "Direct orders this week", documents_generated: "Documents generated", expired_reservations: "Expired reservations",
  expiring_30_days: "Licenses expiring in 30 days", exports_failed: "Sheet exports failed", generated_7_days: "Documents generated in 7 days",
  open_cases: "Open cases", outbox_failed: "Outbox failures", processing: "Orders processing",
  procurement_payments_pending: "Procurement payments pending", settlements_pending: "Consignment settlements pending",
  submitted: "Orders submitted", under_review: "Orders under review", applications_pending: "Applications pending",
  requests_pending: "Discord access requests pending",
};

function Group({ actionHref, actionLabel, title, values }: { actionHref?: string; actionLabel?: string; title: string; values: Record<string, number> }) {
  return <section className="integration-section"><div className="inventory-section-heading"><div><p className="eyebrow">Live authoritative counts</p><h2>{title}</h2></div>{actionHref && actionLabel && <Link className="button button-secondary" href={actionHref}>{actionLabel}</Link>}</div>
    <div className="inventory-summary">{Object.entries(values).map(([key, value]) => <article key={key}><span>{labels[key] ?? key.replaceAll("_", " ")}</span><strong>{value}</strong></article>)}</div></section>;
}

export default async function DashboardPage() {
  const { client } = await requireStaffSession(); const result = await getCommandDashboard(client);
  if (!result.ok && result.denied) return <main className="staff-main"><StaffAccessDenied /></main>;
  if (!result.ok) return <main className="staff-main"><section className="notice-panel"><h1>Command dashboard unavailable</h1><p>No fallback source was used.</p></section></main>;
  const dashboard = result.data; const locale = getDefaultLocale();
  return <main className="staff-main">
    <header className="staff-page-header"><div><p className="eyebrow">Authenticated staff · complete overview</p><h1>EEC command dashboard</h1><p>One live overview of trade demand, inventory pressure, licensing, finance, compliance, documents, and projections.</p></div>
      <div className="staff-button-row"><Link className="button button-primary" href="/staff/launch">Open launch desk</Link>{dashboard.capabilities.can_review_applications&&<Link className="button button-primary" href="/staff/applications">Review applications</Link>}{dashboard.capabilities.can_manage_access&&<Link className="button button-primary" href="/staff/access">Approve staff access</Link>}<Link className="button button-secondary" href="/staff/configuration">Quick inventory & items</Link><Link className="button button-secondary" href="/staff/operations">System health</Link><form action={signOutAction}><button className="button button-secondary">Sign out</button></form></div></header>
    <p className="result-count">Snapshot {new Date(dashboard.generated_at).toLocaleString(locale)}. Every number comes directly from Supabase.</p>
    {dashboard.capabilities.can_manage_access&&<Group actionHref="/staff/access" actionLabel="Review Discord access" title="Staff access" values={dashboard.access} />}
    <Group title="Orders" values={dashboard.orders} /><Group title="Inventory and assets" values={dashboard.inventory} />
    <Group actionHref={dashboard.capabilities.can_review_applications?"/staff/applications":undefined} actionLabel={dashboard.capabilities.can_review_applications?"Review applications":undefined} title="Licensing" values={dashboard.licensing} /><Group title="Finance" values={dashboard.finance} />
    <Group title="Compliance" values={dashboard.compliance} /><Group title="Integrations" values={dashboard.integrations} />
    <Group title="Official documents" values={dashboard.documents} />
    <section className="integration-section"><div className="inventory-section-heading"><div><p className="eyebrow">Newest demand</p><h2>Recent orders</h2></div><Link className="button button-secondary" href="/staff/orders">Full order queue</Link></div>
      <div className="integration-run-list">{dashboard.recent_orders.map((order) => <Link className="integration-run" href={`/staff/orders/${order.id}`} key={order.id}><div><span className="staff-status staff-status-active">{order.status}</span><strong>{order.reference} · {order.customer}</strong><small>{order.channel.replaceAll("_", " ")} · {new Date(order.submitted_at).toLocaleString(locale)}</small></div></Link>)}{dashboard.recent_orders.length===0&&<p>No order has been submitted.</p>}</div></section>
    {dashboard.recent_audit.length>0&&<section className="integration-section"><div className="inventory-section-heading"><div><p className="eyebrow">Independent evidence</p><h2>Recent audit trail</h2></div></div><div className="integration-run-list">{dashboard.recent_audit.map((entry)=><article className="integration-run" key={entry.id}><div><strong>{entry.action} · {entry.record_type}</strong><small>{new Date(entry.occurred_at).toLocaleString(locale)}{entry.reason?` · ${entry.reason}`:""}</small></div></article>)}</div></section>}
  </main>;
}
