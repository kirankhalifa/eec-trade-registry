import Link from "next/link";

import { RelativeTime } from "@/components/relative-time";
import { StaffAccessDenied } from "@/components/staff-access-denied";
import { type IconName, UiIcon } from "@/components/ui-icon";
import { type CommandDashboard, getCommandDashboard } from "@/lib/command-dashboard";
import { requireStaffSession } from "@/lib/staff-auth";

export const dynamic = "force-dynamic";

type CounterGroup = CommandDashboard["orders"];
type AttentionItem = { description: string; href: string; icon: IconName; label: string; value: number };
type Tool = { description: string; href: string; icon: IconName; label: string; ownerOnly?: boolean };

function value(group: CounterGroup, key: string) { return group[key] ?? 0; }

const toolGroups: Array<{ label: string; tools: Tool[] }> = [
  {
    label: "People and authority",
    tools: [
      { href: "/staff/licensing", icon: "license", label: "Licenses", description: "Issue, renew, suspend, and inspect a customer’s authority." },
      { href: "/staff/access", icon: "people", label: "Staff access", description: "Approve Discord identities and manage Agent access.", ownerOnly: true },
      { href: "/staff/configuration", icon: "gear", label: "Reference setup", description: "Add categories, units, license types, and other reusable choices." },
    ],
  },
  {
    label: "Trade and custody",
    tools: [
      { href: "/staff/economy", icon: "coins", label: "Reserve economy", description: "Set material targets and guaranteed purchase offers." },
      { href: "/staff/pricing", icon: "coins", label: "Advanced pricing", description: "Create special business, license, regional, or channel price rules." },
      { href: "/staff/fulfillment", icon: "package", label: "Fulfillment queue", description: "See handoffs across every order when exception work needs a queue." },
      { href: "/staff/transfers", icon: "transfer", label: "Warehouse transfers", description: "Move recorded custody between configured locations." },
      { href: "/staff/consignments", icon: "truck", label: "Consignments", description: "Track Company-owned goods held by a business and settle reports." },
      { href: "/staff/assets", icon: "key", label: "Unique goods", description: "Track individually identified goods and their custody history." },
    ],
  },
  {
    label: "Evidence and system",
    tools: [
      { href: "/staff/documents", icon: "document", label: "Official documents", description: "Generate and download frozen PDF snapshots of authoritative records." },
      { href: "/staff/compliance", icon: "shield", label: "Compliance", description: "Record investigations, findings, appeals, and configured actions." },
      { href: "/staff/integrations", icon: "external", label: "Sheets and Discord", description: "Open the public Sheet, check freshness, and inspect delivery failures." },
      { href: "/staff/operations", icon: "heart", label: "System health", description: "Inspect services, stuck work, and the authoritative audit trail.", ownerOnly: true },
    ],
  },
];

function QuickAction({ description, href, icon, label }: Tool) {
  return (
    <Link className="dashboard-quick-action" href={href}>
      <span><UiIcon name={icon} size={22} /></span>
      <span><strong>{label}</strong><small>{description}</small></span>
      <UiIcon name="arrow" size={16} />
    </Link>
  );
}

export default async function DashboardPage() {
  const { client } = await requireStaffSession();
  const result = await getCommandDashboard(client);
  if (!result.ok && result.denied) return <main className="staff-main"><StaffAccessDenied /></main>;
  if (!result.ok) return <main className="staff-main"><section className="notice-panel"><h1>Today is unavailable</h1><p>The authoritative registry could not be reached. No fallback data is shown.</p></section></main>;

  const dashboard = result.data;
  const isOwner = dashboard.capabilities.can_manage_access;
  const attentionCandidates: AttentionItem[] = [
    { href: "/staff/access", icon: "people", label: "Discord access request", description: "An identity needs an Owner decision.", value: value(dashboard.access, "requests_pending") },
    { href: "/staff/applications", icon: "document", label: "license application", description: "An applicant is waiting for a decision.", value: value(dashboard.licensing, "applications_pending") },
    { href: "/staff/orders", icon: "clipboard", label: "order needing review", description: "Open it and continue from the order page.", value: value(dashboard.orders, "under_review") },
    { href: "/staff/orders", icon: "package", label: "order waiting for stock", description: "Demand is recorded and needs replenishment.", value: value(dashboard.orders, "awaiting_stock") },
    { href: "/staff/inventory", icon: "box", label: "critical reserve", description: "A material is below its configured safety level.", value: value(dashboard.inventory, "critical_reserves") },
    { href: "/staff/inventory", icon: "box", label: "expired stock hold", description: "Review the order before releasing or extending it.", value: value(dashboard.inventory, "expired_reservations") },
    { href: "/staff/economy", icon: "coins", label: "payment outstanding", description: "A supplier purchase or settlement still needs evidence.", value: value(dashboard.finance, "procurement_payments_pending") + value(dashboard.finance, "settlements_pending") },
    { href: "/staff/compliance", icon: "shield", label: "compliance action", description: "A recorded action is waiting for review.", value: value(dashboard.compliance, "actions_pending") },
    { href: "/staff/integrations", icon: "external", label: "Sheet or Discord failure", description: "Business data is safe; its projection needs attention.", value: value(dashboard.integrations, "outbox_failed") + value(dashboard.integrations, "exports_failed") + value(dashboard.integrations, "deliveries_failed") },
  ];
  const attention = attentionCandidates.filter((item) => item.value > 0 && (!item.href.startsWith("/staff/access") || isOwner));
  const quickActions: Tool[] = [
    { href: "/staff/orders/new", icon: "clipboard", label: "Record an order", description: "Choose the buyer, goods, and handoff." },
    { href: "/staff/buy", icon: "coins", label: "Buy materials", description: "Receive player supply at the guaranteed rate." },
    { href: "/staff/applications", icon: "license", label: "Review applications", description: "Approve, renew, or deny a license request." },
    { href: "/staff/inventory", icon: "box", label: "Receive stock", description: "Add ordinary goods or inspect current positions." },
  ];

  return (
    <main className="staff-main dashboard-main">
      <header className="dashboard-header">
        <div><p className="eyebrow">East Empire Company operations</p><h1>Today</h1><p>Start a routine task or handle the few records that actually need attention.</p></div>
      </header>
      <p className="dashboard-meta">Live from Supabase · refreshed <RelativeTime value={dashboard.generated_at} /></p>

      <section aria-labelledby="quick-actions-title" className="dashboard-quick-section">
        <div className="dashboard-section-heading"><div><p className="eyebrow">Everyday work</p><h2 id="quick-actions-title">What do you need to do?</h2></div></div>
        <div className="dashboard-quick-grid">{quickActions.map((action) => <QuickAction key={action.href} {...action} />)}</div>
      </section>

      <div className="dashboard-layout">
        <section className="dashboard-panel">
          <header className="dashboard-panel-header"><div><h2>Needs attention</h2><p>Only exceptions and decisions appear here.</p></div></header>
          {attention.length > 0 ? (
            <ul className="dashboard-attention-list">{attention.map((item) => (
              <li key={item.label}><Link className="dashboard-attention-item" href={item.href}><span><UiIcon name={item.icon} size={16} /></span><span><strong>{item.value} {item.label}{item.value === 1 ? "" : "s"}</strong><small>{item.description}</small></span><UiIcon name="arrow" size={15} /></Link></li>
            ))}</ul>
          ) : <div className="dashboard-clear-state"><UiIcon name="check" size={22} /><div><strong>Nothing needs immediate attention.</strong><p>You can start a new order or material purchase above.</p></div></div>}
        </section>

        <section className="dashboard-panel">
          <header className="dashboard-panel-header"><div><h2>Recent orders</h2><p>Open an order once and finish the work there.</p></div><Link href="/staff/orders">View all</Link></header>
          {dashboard.recent_orders.length > 0 ? <ul className="dashboard-activity-list">{dashboard.recent_orders.slice(0, 6).map((order) => (
            <li key={order.id}><Link className="dashboard-activity-item" href={`/staff/orders/${order.id}`}><span className="dashboard-activity-mark" /><span><strong>{order.customer}</strong><small>{order.status.replaceAll("_", " ")} · <RelativeTime value={order.submitted_at} /></small></span><UiIcon name="arrow" size={14} /></Link></li>
          ))}</ul> : <div className="dashboard-empty dashboard-empty-action"><p>No orders yet.</p><Link className="button button-primary button-compact" href="/staff/orders/new">Record the first order</Link></div>}
        </section>
      </div>

      <details className="staff-tools-panel">
        <summary><span><UiIcon name="gear" size={19} /><span><strong>Staff tools</strong><small>Advanced records, policy, custody, documents, and system controls</small></span></span><span>Open tools</span></summary>
        <div className="staff-tools-content">
          <p className="staff-tools-explanation"><strong>These tools are part of the system, but they are not part of an ordinary order.</strong> Open them only when the task specifically involves the subject described. Permissions are still checked by Supabase.</p>
          <div className="staff-tools-groups">{toolGroups.map((group) => {
            const tools = group.tools.filter((tool) => !tool.ownerOnly || isOwner);
            return <section key={group.label}><h3>{group.label}</h3><div>{tools.map((tool) => <QuickAction key={tool.href} {...tool} />)}</div></section>;
          })}</div>
          {dashboard.recent_audit.length > 0 && isOwner && <details className="staff-activity-panel"><summary>Recent authoritative staff changes</summary><ul>{dashboard.recent_audit.slice(0, 6).map((entry) => <li key={entry.id}><strong>{entry.action.replaceAll("_", " ")}</strong><span>{entry.record_type.replace("public.", "").replaceAll("_", " ")} · <RelativeTime value={entry.occurred_at} /></span></li>)}</ul></details>}
        </div>
      </details>
    </main>
  );
}
