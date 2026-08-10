import Link from "next/link";

import { signOutAction } from "@/app/staff/actions";
import { grantRoleAction, revokeRoleAction } from "@/app/staff/operations/actions";
import { StaffAccessDenied } from "@/components/staff-access-denied";
import { StaffNotice } from "@/components/staff-notice";
import { getDefaultLocale } from "@/lib/env";
import { requireStaffSession } from "@/lib/staff-auth";
import { getStaffOperationsWorkspace } from "@/lib/staff-operations";

export const dynamic = "force-dynamic";

interface OperationsPageProps {
  searchParams: Promise<{ error?: string; notice?: string }>;
}

function stateClass(active: boolean): string {
  return `staff-status staff-status-${active ? "active" : "inactive"}`;
}

function scopeLabel(scope: Record<string, unknown>): string {
  return Object.keys(scope).length === 0 ? "global" : JSON.stringify(scope);
}

export default async function OperationsPage({ searchParams }: OperationsPageProps) {
  const parameters = await searchParams;
  const { client } = await requireStaffSession();
  const result = await getStaffOperationsWorkspace(client);
  if (!result.ok && result.code === "access_denied") {
    return <main className="staff-main"><StaffAccessDenied /></main>;
  }
  if (!result.ok) {
    return (
      <main className="staff-main">
        <section className="notice-panel">
          <p className="eyebrow">Operations console unavailable</p>
          <h1>Authoritative operational state could not be loaded</h1>
          <p>No fallback source was used and no authority was changed.</p>
        </section>
      </main>
    );
  }

  const workspace = result.data;
  const locale = getDefaultLocale();
  const health = [
    ["Outbox ready", workspace.health.outbox_pending],
    ["Outbox failed", workspace.health.outbox_failed],
    ["Delivery failed", workspace.health.delivery_failed],
    ["Expired delivery leases", workspace.health.delivery_lease_expired],
    ["Export failed", workspace.health.export_failed],
    ["Expired export leases", workspace.health.export_lease_expired],
    ["Overdue export definitions", workspace.health.export_definitions_overdue],
    ["Expired fungible reservations", workspace.health.reservations_expired_active],
    ["Expired asset reservations", workspace.health.asset_reservations_expired_active],
    ["Transfers in transit/dispute", workspace.health.transfers_in_transit],
    ["Open compliance cases", workspace.health.compliance_open],
  ] as const;

  return (
    <main className="staff-main">
      <header className="staff-page-header">
        <div>
          <p className="eyebrow">Authenticated staff · platform operations</p>
          <h1>Access and operational readiness</h1>
          <p>
            Review effective authority, grant or revoke scoped roles, and inspect
            policy-neutral health signals without bypassing secure functions.
          </p>
        </div>
        <div className="staff-button-row">
          <Link className="button button-secondary" href="/staff">Catalogue</Link>
          <Link className="button button-secondary" href="/staff/integrations">Integrations</Link>
          <Link className="button button-secondary" href="/staff/compliance">Compliance</Link>
          <form action={signOutAction}><button className="button button-secondary" type="submit">Sign out</button></form>
        </div>
      </header>

      <StaffNotice error={parameters.error} notice={parameters.notice} />

      <section className="inventory-summary" aria-label="Operational health">
        {health.map(([label, value]) => (
          <article key={label}><span>{label}</span><strong>{value}</strong></article>
        ))}
      </section>
      <p className="result-count">
        Snapshot generated {new Date(workspace.generated_at).toLocaleString(locale)}.
        Counts identify work for review; they do not perform automatic corrections.
      </p>

      {workspace.capabilities.can_manage_assignments && (
        <section className="integration-section">
          <div className="inventory-section-heading">
            <div><p className="eyebrow">Effective-dated authority</p><h2>Grant a staff role</h2></div>
            <p>Authentication alone grants no authority. Every grant is audited and retry-safe.</p>
          </div>
          <form action={grantRoleAction} className="integration-form">
            <label className="field">
              <span>Staff actor</span>
              <select name="actor_id" required>
                {workspace.actors.filter((actor) => actor.status === "active").map((actor) => (
                  <option key={actor.id} value={actor.id}>{actor.display_name}</option>
                ))}
              </select>
            </label>
            <label className="field">
              <span>Assignable role</span>
              <select name="role_id" required>
                {workspace.roles.map((role) => (
                  <option key={role.id} value={role.id}>{role.display_name}{role.is_elevated ? " · elevated" : ""}</option>
                ))}
              </select>
            </label>
            <label className="field">
              <span>Effective until (optional)</span>
              <input name="effective_until" type="datetime-local" />
            </label>
            <label className="field">
              <span>Scope JSON (optional)</span>
              <textarea maxLength={4000} name="assignment_scope" placeholder={'{"warehouse_ids":["..."]}'} rows={3} />
              <small>Leave blank for global scope. Scope keys only constrain permissions whose policy recognizes them.</small>
            </label>
            <label className="field">
              <span>Audit reason</span>
              <input maxLength={500} name="reason" required />
            </label>
            <button className="button button-primary" type="submit">Grant role immediately</button>
          </form>
        </section>
      )}

      <section className="integration-section">
        <div className="inventory-section-heading">
          <div><p className="eyebrow">Staff identities</p><h2>Current and historical assignments</h2></div>
          <p>The last active platform administrator cannot be revoked.</p>
        </div>
        <div className="integration-grid">
          {workspace.actors.map((actor) => (
            <article className="integration-card" key={actor.id}>
              <header>
                <div>
                  <span className={stateClass(actor.status === "active")}>{actor.status}</span>
                  <h3>{actor.display_name}</h3>
                  <p>{actor.assignments.filter((assignment) => assignment.active_now).length} active assignment(s)</p>
                </div>
              </header>
              <div className="integration-run-list">
                {actor.assignments.map((assignment) => (
                  <article className="integration-run" key={assignment.id}>
                    <div>
                      <span className={stateClass(assignment.active_now)}>{assignment.active_now ? "active" : assignment.revoked_at ? "revoked" : "scheduled/ended"}</span>
                      <strong>{assignment.role_name}</strong>
                      <small>
                        {scopeLabel(assignment.assignment_scope)} · from {new Date(assignment.effective_from).toLocaleString(locale)}
                        {assignment.effective_until ? ` · until ${new Date(assignment.effective_until).toLocaleString(locale)}` : ""}
                      </small>
                    </div>
                    {workspace.capabilities.can_manage_assignments && assignment.active_now && (
                      <form action={revokeRoleAction} className="integration-replay">
                        <input name="assignment_id" type="hidden" value={assignment.id} />
                        <input aria-label={`Revocation reason for ${assignment.role_name}`} maxLength={500} name="reason" placeholder="Revocation reason" required />
                        <button className="button button-secondary" type="submit">Revoke</button>
                      </form>
                    )}
                  </article>
                ))}
                {actor.assignments.length === 0 && <p>No role has been assigned.</p>}
              </div>
            </article>
          ))}
        </div>
      </section>

      <section className="integration-section">
        <div className="inventory-section-heading">
          <div><p className="eyebrow">Composable roles</p><h2>Permission catalogue</h2></div>
          <p>Roles remain configuration; business functions recheck exact permissions at execution time.</p>
        </div>
        <div className="integration-grid">
          {workspace.roles.map((role) => (
            <article className="integration-card" key={role.id}>
              <header><div><span className={stateClass(role.is_elevated)}>{role.is_elevated ? "elevated" : "standard"}</span><h3>{role.display_name}</h3><p>{role.description}</p></div></header>
              <ul>{role.permissions.map((permission) => <li key={permission.code}><code>{permission.code}</code> · {permission.display_name}</li>)}</ul>
            </article>
          ))}
        </div>
      </section>

      {workspace.capabilities.can_read_audit && (
        <section className="integration-section">
          <div className="inventory-section-heading"><div><p className="eyebrow">Independent evidence</p><h2>Recent access audit</h2></div><p>Latest 100 access-control mutations.</p></div>
          <div className="integration-run-list">
            {workspace.recent_access_audit.map((entry) => (
              <article className="integration-run" key={entry.id}>
                <div><span className="staff-status staff-status-active">{entry.action}</span><strong>{entry.record_type}</strong><small>{new Date(entry.created_at).toLocaleString(locale)} · {entry.actor_name ?? "database operator"}</small></div>
                <div>{entry.reason && <span>{entry.reason}</span>}</div>
              </article>
            ))}
            {workspace.recent_access_audit.length === 0 && <p>No access mutation has been recorded.</p>}
          </div>
        </section>
      )}
    </main>
  );
}
