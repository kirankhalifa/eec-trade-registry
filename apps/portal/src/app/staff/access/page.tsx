import Link from "next/link";

import { reviewStaffAccessAction } from "@/app/staff/access/actions";
import { StaffAccessDenied } from "@/components/staff-access-denied";
import { StaffNotice } from "@/components/staff-notice";
import { getDefaultLocale } from "@/lib/env";
import { getOwnerAccessWorkspace, type OwnerAccessWorkspace } from "@/lib/staff-access";
import { requireStaffSession } from "@/lib/staff-auth";

export const dynamic = "force-dynamic";

interface AccessPageProps { searchParams: Promise<{ error?: string; notice?: string }> }

function AccessRequestCard({ request, locale }: {
  request: OwnerAccessWorkspace["requests"][number];
  locale: string;
}) {
  const actionable = request.status !== "approved";
  return <article className="integration-card">
    <header><div><span className={`staff-status staff-status-${request.status === "approved" ? "active" : "inactive"}`}>{request.status}</span><h3>{request.display_name}</h3><p>Discord ID {request.discord_user_id}</p></div><strong>v{request.version}</strong></header>
    <dl className="staff-item-facts">
      <div><dt>First request</dt><dd>{new Date(request.requested_at).toLocaleString(locale)}</dd></div>
      <div><dt>Last sign-in attempt</dt><dd>{new Date(request.last_attempted_at).toLocaleString(locale)}</dd></div>
      {request.reviewed_at && <div><dt>Last reviewed</dt><dd>{new Date(request.reviewed_at).toLocaleString(locale)}</dd></div>}
      {request.review_reason && <div><dt>Owner note</dt><dd>{request.review_reason}</dd></div>}
    </dl>
    {!request.protected_owner && <form action={reviewStaffAccessAction} className="integration-form">
      <input name="access_request_id" type="hidden" value={request.id}/>
      <input name="expected_version" type="hidden" value={request.version}/>
      <label className="field"><span>Decision</span><select name="decision" defaultValue={actionable ? "approve" : "block"}>
        {actionable && <option value="approve">Approve as Agent</option>}
        {request.status !== "approved" && <option value="deny">Deny access</option>}
        <option value="block">Block this identity</option>
      </select></label>
      <label className="field"><span>Reason / owner note</span><input maxLength={500} name="reason" placeholder="Why this access decision is appropriate" required/></label>
      <button className={actionable ? "button button-primary" : "button button-secondary"}>{actionable ? "Record access decision" : "Block Agent access"}</button>
    </form>}
    {request.protected_owner && <p><strong>Protected Owner identity.</strong> Owner authority cannot be changed from the Agent approval queue.</p>}
  </article>;
}

export default async function StaffAccessPage({ searchParams }: AccessPageProps) {
  const parameters = await searchParams;
  const { client } = await requireStaffSession();
  const result = await getOwnerAccessWorkspace(client);
  if (!result.ok && result.denied) return <main className="staff-main"><StaffAccessDenied /></main>;
  if (!result.ok) return <main className="staff-main"><section className="notice-panel"><h1>Access queue unavailable</h1><p>No authority was changed and no fallback source was used.</p></section></main>;

  const locale = getDefaultLocale();
  const pending = result.data.requests.filter((request) => request.status === "pending");
  const reviewed = result.data.requests.filter((request) => request.status !== "pending");

  return <main className="staff-main">
    <header className="staff-page-header"><div><p className="eyebrow">Owner only · Discord access control</p><h1>Staff access</h1><p>Discord confirms identity; your decision here determines whether that person becomes an Agent.</p></div><div className="staff-button-row"><Link className="button button-secondary" href="/staff/operations">View access audit</Link></div></header>
    <StaffNotice error={parameters.error} notice={parameters.notice}/>

    <section className="inventory-summary" aria-label="Access overview">
      <article><span>Pending approval</span><strong>{pending.length}</strong></article>
      <article><span>Owners</span><strong>{result.data.staff.filter((member) => member.access_class === "owner").length}</strong></article>
      <article><span>Agents</span><strong>{result.data.staff.filter((member) => member.access_class === "agent").length}</strong></article>
    </section>

    <section className="integration-section"><div className="inventory-section-heading"><div><p className="eyebrow">Needs your decision</p><h2>Pending Discord sign-ins</h2></div><p>Approving grants the single day-to-day Agent access class. Nothing is granted merely by appearing here.</p></div><div className="integration-grid">{pending.map((request) => <AccessRequestCard key={request.id} locale={locale} request={request}/>)}{pending.length === 0 && <p>No Discord identity is waiting for approval.</p>}</div></section>

    <section className="integration-section"><div className="inventory-section-heading"><div><p className="eyebrow">Simple public model</p><h2>Who gets what</h2></div></div><div className="integration-grid">
      <article className="integration-card"><h3>Owner</h3><p>You. Full platform authority, staff approvals, audit, configuration, and operations.</p></article>
      <article className="integration-card"><h3>Agent</h3><p>Authorized EEC staff. Handles day-to-day orders, stock, licensing, dealers, finance, and compliance.</p></article>
      <article className="integration-card"><h3>Business</h3><p>Not a staff role. Business access is restricted to a specific dealer/business relationship through the Dealer portal.</p></article>
      <article className="integration-card"><h3>Public</h3><p>No login. Catalogue, verification, application intake, and public projections only.</p></article>
    </div></section>

    <section className="integration-section"><div className="inventory-section-heading"><div><p className="eyebrow">Currently authorized</p><h2>Owner and Agent roster</h2></div></div><div className="integration-grid">{result.data.staff.map((member) => <article className="integration-card" key={member.actor_id}><header><div><span className="staff-status staff-status-active">{member.access_class}</span><h3>{member.display_name}</h3><p>{member.discord_user_id ? `Discord ID ${member.discord_user_id}` : "Legacy identity binding"}</p></div></header><small>Active since {new Date(member.active_since).toLocaleString(locale)}</small></article>)}</div></section>

    {reviewed.length > 0 && <section className="integration-section"><div className="inventory-section-heading"><div><p className="eyebrow">Decision history</p><h2>Reviewed access requests</h2></div></div><div className="integration-grid">{reviewed.map((request) => <AccessRequestCard key={request.id} locale={locale} request={request}/>)}</div></section>}
  </main>;
}
