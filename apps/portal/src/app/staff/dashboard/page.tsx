import Link from "next/link";

import { RelativeTime } from "@/components/relative-time";
import { StaffAccessDenied } from "@/components/staff-access-denied";
import { type IconName, UiIcon } from "@/components/ui-icon";
import { type CommandDashboard, getCommandDashboard } from "@/lib/command-dashboard";
import { requireStaffSession } from "@/lib/staff-auth";

export const dynamic = "force-dynamic";

type CounterGroup = CommandDashboard["orders"];
type PriorityCard = { href: string; icon: IconName; label: string; value: number; tone?: "urgent" | "warning" };
type AttentionItem = { description: string; href: string; icon: IconName; label: string; value: number };

function value(group: CounterGroup, key: string) { return group[key] ?? 0; }

function Priority({ card }: { card: PriorityCard }) {
  const tone = card.tone ? ` is-${card.tone}` : "";
  return <Link className={`dashboard-stat${tone}`} href={card.href}><span>{card.label}<UiIcon name={card.icon}/></span><strong>{card.value}</strong><small>Open workspace <UiIcon name="arrow" size={13}/></small></Link>;
}

export default async function DashboardPage() {
  const { client } = await requireStaffSession();
  const result = await getCommandDashboard(client);
  if (!result.ok && result.denied) return <main className="staff-main"><StaffAccessDenied /></main>;
  if (!result.ok) return <main className="staff-main"><section className="notice-panel"><h1>Dashboard unavailable</h1><p>The authoritative registry could not be reached. No fallback data is shown.</p></section></main>;

  const dashboard = result.data;
  const priorityCards: PriorityCard[] = [
    { href: "/staff/applications", icon: "document", label: "Applications waiting", value: value(dashboard.licensing,"applications_pending"), tone: value(dashboard.licensing,"applications_pending") > 0 ? "urgent" : undefined },
    { href: "/staff/orders", icon: "clipboard", label: "Orders to review", value: value(dashboard.orders,"under_review"), tone: value(dashboard.orders,"under_review") > 0 ? "urgent" : undefined },
    { href: "/staff/orders", icon: "package", label: "Awaiting stock", value: value(dashboard.orders,"awaiting_stock"), tone: value(dashboard.orders,"awaiting_stock") > 0 ? "warning" : undefined },
    { href: "/staff/inventory", icon: "box", label: "Critical reserves", value: value(dashboard.inventory,"critical_reserves"), tone: value(dashboard.inventory,"critical_reserves") > 0 ? "warning" : undefined },
  ];
  const attentionCandidates: AttentionItem[] = [
    { href: "/staff/access", icon: "people", label: "Discord access request", description: "An identity needs an Owner decision.", value: value(dashboard.access,"requests_pending") },
    { href: "/staff/compliance", icon: "shield", label: "Compliance action", description: "A recorded action is waiting for review.", value: value(dashboard.compliance,"actions_pending") },
    { href: "/staff/integrations", icon: "external", label: "Integration failure", description: "An export or delivery needs attention.", value: value(dashboard.integrations,"outbox_failed") + value(dashboard.integrations,"exports_failed") + value(dashboard.integrations,"deliveries_failed") },
    { href: "/staff/inventory", icon: "box", label: "Expired reservation", description: "A stock claim needs operational review.", value: value(dashboard.inventory,"expired_reservations") },
    { href: "/staff/licensing", icon: "license", label: "License expiring soon", description: "Review authority ending in the next 30 days.", value: value(dashboard.licensing,"expiring_30_days") },
    { href: "/staff/economy", icon: "coins", label: "Payment outstanding", description: "A procurement or settlement record is pending.", value: value(dashboard.finance,"procurement_payments_pending") + value(dashboard.finance,"settlements_pending") },
  ];
  const attention = attentionCandidates.filter((item) => item.value > 0);

  return <main className="staff-main">
    <header className="dashboard-header"><div><p className="eyebrow">Today at a glance</p><h1>Command dashboard</h1><p>Handle exceptions here. Use “Find or do anything” whenever you already know what you need.</p></div><div className="dashboard-actions"><Link className="button button-primary" href="/staff/launch#enter-order"><UiIcon name="clipboard"/>Create order</Link><Link className="button button-secondary" href="/staff/configuration"><UiIcon name="box"/>Add item or stock</Link></div></header>
    <p className="dashboard-meta">Live from Supabase · refreshed <RelativeTime value={dashboard.generated_at}/></p>

    <section className="dashboard-priority-grid" aria-label="Priority counts">{priorityCards.map((card)=><Priority card={card} key={card.label}/>)}</section>

    <div className="dashboard-layout"><div>
      <section className="dashboard-panel"><header className="dashboard-panel-header"><div><h2>Recent orders</h2><p>Open an order once and keep working there until handoff.</p></div><Link href="/staff/orders">View all</Link></header>{dashboard.recent_orders.length > 0 ? <ul className="dashboard-activity-list">{dashboard.recent_orders.map((order)=><li key={order.id}><Link className="dashboard-activity-item" href={`/staff/orders/${order.id}`}><span className="dashboard-activity-mark"/><span><strong>{order.reference} · {order.customer}</strong><small>{order.status.replaceAll("_"," ")} · {order.channel.replaceAll("_"," ")} · <RelativeTime value={order.submitted_at}/></small></span></Link></li>)}</ul> : <div className="dashboard-empty dashboard-empty-action"><p>No orders have been submitted yet.</p><Link className="button button-primary button-compact" href="/staff/launch#enter-order">Create the first order</Link></div>}</section>
    </div><aside>
      <section className="dashboard-panel"><header className="dashboard-panel-header"><div><h2>Needs attention</h2><p>Exceptions and decisions, not routine noise.</p></div></header>{attention.length > 0 ? <ul className="dashboard-attention-list">{attention.map((item)=><li key={item.label}><Link className="dashboard-attention-item" href={item.href}><span><UiIcon name={item.icon} size={16}/></span><span><strong>{item.value} {item.label}{item.value === 1 ? "" : "s"}</strong><small>{item.description}</small></span><UiIcon name="arrow" size={15}/></Link></li>)}</ul> : <p className="dashboard-empty">Nothing needs immediate attention. Routine operations are ready.</p>}</section>

      <section className="dashboard-panel"><header className="dashboard-panel-header"><div><h2>Recent staff activity</h2><p>Human decisions and authoritative changes.</p></div><Link href="/staff/operations">System health</Link></header>{dashboard.recent_audit.length > 0 ? <ul className="dashboard-activity-list">{dashboard.recent_audit.slice(0,6).map((entry)=><li className="dashboard-activity-item" key={entry.id}><span className="dashboard-activity-mark"/><span><strong>{entry.action} · {entry.record_type.replace("public.","").replaceAll("_"," ")}</strong><small><RelativeTime value={entry.occurred_at}/>{entry.reason ? ` · ${entry.reason}` : ""}</small></span></li>)}</ul> : <p className="dashboard-empty">No recent staff actions.</p>}</section>
    </aside></div>
  </main>;
}
