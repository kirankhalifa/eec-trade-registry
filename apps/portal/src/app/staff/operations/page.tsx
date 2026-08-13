import Link from "next/link";

import { StaffAccessDenied } from "@/components/staff-access-denied";
import { StaffNotice } from "@/components/staff-notice";
import { getDefaultLocale } from "@/lib/env";
import { requireStaffSession } from "@/lib/staff-auth";
import { getStaffOperationsWorkspace } from "@/lib/staff-operations";

export const dynamic = "force-dynamic";

interface OperationsPageProps { searchParams: Promise<{ error?: string; notice?: string }> }

export default async function OperationsPage({ searchParams }: OperationsPageProps) {
  const parameters = await searchParams;
  const { client } = await requireStaffSession();
  const result = await getStaffOperationsWorkspace(client);
  if (!result.ok && result.code === "access_denied") return <main className="staff-main"><StaffAccessDenied /></main>;
  if (!result.ok) return <main className="staff-main"><section className="notice-panel"><h1>System health unavailable</h1><p>No fallback source was used and no authority was changed.</p></section></main>;

  const workspace = result.data;
  const locale = getDefaultLocale();
  const health = [
    ["Outbox ready", workspace.health.outbox_pending],
    ["Outbox failed", workspace.health.outbox_failed],
    ["Discord delivery failed", workspace.health.delivery_failed],
    ["Expired delivery leases", workspace.health.delivery_lease_expired],
    ["Sheet export failed", workspace.health.export_failed],
    ["Expired export leases", workspace.health.export_lease_expired],
    ["Overdue export schedules", workspace.health.export_definitions_overdue],
    ["Expired stock reservations", workspace.health.reservations_expired_active],
    ["Expired unique reservations", workspace.health.asset_reservations_expired_active],
    ["Transfers in transit/dispute", workspace.health.transfers_in_transit],
    ["Open compliance cases", workspace.health.compliance_open],
  ] as const;

  return <main className="staff-main">
    <header className="staff-page-header"><div><p className="eyebrow">Owner only · platform readiness</p><h1>System health</h1><p>Monitor failures, expired work, and recent access-control evidence without wading through routine administration.</p></div><div className="staff-button-row"><Link className="button button-primary" href="/staff/access">Review staff access</Link><Link className="button button-secondary" href="/staff/integrations">Integration details</Link></div></header>
    <StaffNotice error={parameters.error} notice={parameters.notice}/>
    <section className="inventory-summary" aria-label="Operational health">{health.map(([label, value]) => <article key={label}><span>{label}</span><strong>{value}</strong></article>)}</section>
    <p className="result-count">Snapshot generated {new Date(workspace.generated_at).toLocaleString(locale)}. Counts identify work for review; they do not perform automatic corrections.</p>
    {workspace.capabilities.can_read_audit && <section className="integration-section"><div className="inventory-section-heading"><div><p className="eyebrow">Independent evidence</p><h2>Recent access audit</h2></div><p>The latest 100 access-control mutations.</p></div><div className="integration-run-list">{workspace.recent_access_audit.map((entry) => <article className="integration-run" key={entry.id}><div><span className="staff-status staff-status-active">{entry.action}</span><strong>{entry.record_type}</strong><small>{new Date(entry.created_at).toLocaleString(locale)} · {entry.actor_name ?? "database operation"}</small></div><div>{entry.reason && <span>{entry.reason}</span>}</div></article>)}{workspace.recent_access_audit.length === 0 && <p>No access mutation has been recorded.</p>}</div></section>}
  </main>;
}
