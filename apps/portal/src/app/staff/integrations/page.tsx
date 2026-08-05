import Link from "next/link";

import {
  configureIntegrationDestinationAction,
  queueExportRunAction,
  replayExportRunAction,
  replayIntegrationDeliveryAction,
  setExportDefinitionStatusAction,
} from "@/app/staff/integrations/actions";
import { signOutAction } from "@/app/staff/actions";
import { StaffAccessDenied } from "@/components/staff-access-denied";
import { StaffNotice } from "@/components/staff-notice";
import { getDefaultLocale } from "@/lib/env";
import { getIntegrationRuntimeStatus } from "@/lib/integration-env";
import { requireStaffSession } from "@/lib/staff-auth";
import {
  getStaffIntegrationWorkspace,
  googleSpreadsheetUrl,
} from "@/lib/staff-integrations";

export const dynamic = "force-dynamic";

interface IntegrationsPageProps {
  searchParams: Promise<{ error?: string; notice?: string }>;
}

function stateClass(status: string): string {
  return `staff-status staff-status-${status.replaceAll("_", "-")}`;
}

export default async function IntegrationsPage({ searchParams }: IntegrationsPageProps) {
  const parameters = await searchParams;
  const { client } = await requireStaffSession();
  const result = await getStaffIntegrationWorkspace(client);
  if (!result.ok && result.code === "access_denied") {
    return <main className="staff-main"><StaffAccessDenied /></main>;
  }
  if (!result.ok) {
    return (
      <main className="staff-main">
        <section className="notice-panel">
          <p className="eyebrow">Integration console unavailable</p>
          <h1>Operational state could not be loaded</h1>
          <p>No fallback source was used and no authoritative data was changed.</p>
        </section>
      </main>
    );
  }

  const workspace = result.data;
  const runtime = getIntegrationRuntimeStatus();
  const locale = getDefaultLocale();
  const destinationById = new Map(
    workspace.destinations.map((destination) => [destination.id, destination]),
  );

  return (
    <main className="staff-main">
      <header className="staff-page-header">
        <div>
          <p className="eyebrow">Authenticated staff · integration operations</p>
          <h1>Projection and notification console</h1>
          <p>
            Configure non-secret destination identifiers, publish one-way public
            registry snapshots, and monitor retryable Discord delivery work.
          </p>
        </div>
        <div className="staff-button-row">
          <Link className="button button-secondary" href="/staff">Catalogue desk</Link>
          <Link className="button button-secondary" href="/staff/orders">Order desk</Link>
          <form action={signOutAction}>
            <button className="button button-secondary" type="submit">Sign out</button>
          </form>
        </div>
      </header>

      <StaffNotice error={parameters.error} notice={parameters.notice} />

      <section className="inventory-summary" aria-label="Integration health">
        <article><span>Outbox pending</span><strong>{workspace.outbox.pending}</strong></article>
        <article><span>Processing</span><strong>{workspace.outbox.processing}</strong></article>
        <article><span>Failed</span><strong>{workspace.outbox.failed}</strong></article>
        <article><span>Last refresh</span><strong>{new Date(workspace.generated_at).toLocaleTimeString(locale)}</strong></article>
      </section>

      <section className="integration-readiness" aria-label="Server integration configuration">
        {[
          ["Worker authority", runtime.serviceRole],
          ["Worker secret", runtime.cron],
          ["Supabase 15-minute job", workspace.scheduler.active],
          ["Google Sheets", runtime.googleSheets],
          ["Discord endpoint", runtime.discordInteractions],
          ["Discord delivery", runtime.discordDelivery],
          ["Command registration", runtime.discordRegistration],
        ].map(([label, ready]) => (
          <div key={String(label)}>
            <span className={stateClass(ready ? "active" : "inactive")}>{ready ? "ready" : "missing"}</span>
            <strong>{label}</strong>
          </div>
        ))}
      </section>

      <p className="result-count">
        Scheduler: {workspace.scheduler.active ? "active" : "inactive"}. Last database trigger: {workspace.scheduler.last_run_at ? `${new Date(workspace.scheduler.last_run_at).toLocaleString(locale)} (${workspace.scheduler.last_run_status ?? "unknown"})` : "not run yet"}.
      </p>

      <section className="integration-section">
        <div className="inventory-section-heading">
          <div><p className="eyebrow">Destinations</p><h2>External projections</h2></div>
          <p>Only identifiers are stored here. Credentials remain in the managed server environment.</p>
        </div>
        <div className="integration-grid">
          {workspace.destinations.map((destination) => (
            <article className="integration-card" key={destination.id}>
              <header>
                <div>
                  <span className={stateClass(destination.active ? "active" : "inactive")}>
                    {destination.active ? "active" : "inactive"}
                  </span>
                  <h3>{destination.display_name}</h3>
                  <p>{destination.destination_type.replaceAll("_", " ")} · {destination.visibility.replaceAll("_", " ")}</p>
                </div>
                {destination.destination_type === "google_sheets" && destination.external_reference && (
                  <a className="button button-secondary" href={googleSpreadsheetUrl(destination.external_reference)} rel="noreferrer" target="_blank">
                    Open public Sheet
                  </a>
                )}
              </header>
              <form action={configureIntegrationDestinationAction} className="integration-form">
                <input name="destination_id" type="hidden" value={destination.id} />
                <input name="expected_version" type="hidden" value={destination.version} />
                <label className="field">
                  <span>{destination.destination_type === "google_sheets" ? "Google spreadsheet ID" : "Discord channel ID"}</span>
                  <input defaultValue={destination.external_reference ?? ""} maxLength={256} name="external_reference" placeholder="Not configured" />
                </label>
                <label className="staff-checkbox-field">
                  <input defaultChecked={destination.active} name="active" type="checkbox" />
                  <span>Destination active</span>
                </label>
                <label className="field">
                  <span>Audit reason</span>
                  <input maxLength={500} name="reason" placeholder="Why this configuration is changing" required />
                </label>
                <button className="button button-primary" type="submit">Save destination</button>
              </form>
            </article>
          ))}
        </div>
      </section>

      <section className="integration-section">
        <div className="inventory-section-heading">
          <div><p className="eyebrow">Google Sheets</p><h2>Public export schedules</h2></div>
          <p>Each tab is replaced from Supabase every {workspace.definitions[0]?.refresh_interval_minutes ?? 15} minutes. Sheet edits are never imported.</p>
        </div>
        <div className="integration-grid">
          {workspace.definitions.map((definition) => {
            const destination = destinationById.get(definition.destination_id);
            const runnable = definition.active && destination?.active;
            return (
              <article className="integration-card" key={definition.id}>
                <header>
                  <div>
                    <span className={stateClass(definition.active ? "active" : "inactive")}>{definition.active ? "scheduled" : "paused"}</span>
                    <h3>{definition.display_name}</h3>
                    <p>{definition.sheet_tab_name} · {definition.column_contract.length} columns · every {definition.refresh_interval_minutes} minutes</p>
                  </div>
                  <p>Next: {new Date(definition.next_run_at).toLocaleString(locale)}</p>
                </header>
                <div className="integration-action-grid">
                  <form action={setExportDefinitionStatusAction} className="integration-form">
                    <input name="definition_id" type="hidden" value={definition.id} />
                    <input name="expected_version" type="hidden" value={definition.version} />
                    <label className="staff-checkbox-field"><input defaultChecked={definition.active} name="active" type="checkbox" /><span>Scheduled export active</span></label>
                    <label className="field"><span>Audit reason</span><input maxLength={500} name="reason" required /></label>
                    <button className="button button-secondary" type="submit">Save schedule</button>
                  </form>
                  <form action={queueExportRunAction} className="integration-form">
                    <input name="definition_id" type="hidden" value={definition.id} />
                    <label className="field"><span>Manual run reason</span><input maxLength={500} name="reason" required /></label>
                    <button className="button button-primary" disabled={!runnable} type="submit">Queue snapshot now</button>
                    {!runnable && <small>Activate both the destination and this schedule first.</small>}
                  </form>
                </div>
              </article>
            );
          })}
        </div>
      </section>

      <section className="integration-section">
        <div className="inventory-section-heading"><div><p className="eyebrow">Recent work</p><h2>Export runs</h2></div><p>Most recent 50 attempts.</p></div>
        <div className="integration-run-list">
          {workspace.export_runs.map((run) => (
            <article className="integration-run" key={run.id}>
              <div><span className={stateClass(run.status)}>{run.status}</span><strong>{run.definition_code}</strong><small>{new Date(run.created_at).toLocaleString(locale)} · attempt {run.attempt_count}</small></div>
              <div><span>{run.row_count === null ? "No completed snapshot" : `${run.row_count} rows`}</span>{run.last_error && <code>{run.last_error}</code>}</div>
              {run.status === "failed" && (
                <form action={replayExportRunAction} className="integration-replay">
                  <input name="export_run_id" type="hidden" value={run.id} />
                  <input aria-label="Replay reason" maxLength={500} name="reason" placeholder="Replay reason" required />
                  <button className="button button-secondary" type="submit">Replay</button>
                </form>
              )}
            </article>
          ))}
          {workspace.export_runs.length === 0 && <p>No export run has been queued yet.</p>}
        </div>
      </section>

      <section className="integration-section">
        <div className="inventory-section-heading"><div><p className="eyebrow">Recent work</p><h2>Discord deliveries</h2></div><p>Most recent 50 deliveries.</p></div>
        <div className="integration-run-list">
          {workspace.deliveries.map((delivery) => (
            <article className="integration-run" key={delivery.id}>
              <div><span className={stateClass(delivery.status)}>{delivery.status}</span><strong>{delivery.event_type}</strong><small>{delivery.destination_code} · {new Date(delivery.created_at).toLocaleString(locale)} · attempt {delivery.attempt_count}</small></div>
              <div>{delivery.last_error && <code>{delivery.last_error}</code>}</div>
              {delivery.status === "failed" && (
                <form action={replayIntegrationDeliveryAction} className="integration-replay">
                  <input name="delivery_id" type="hidden" value={delivery.id} />
                  <input aria-label="Replay reason" maxLength={500} name="reason" placeholder="Replay reason" required />
                  <button className="button button-secondary" type="submit">Replay</button>
                </form>
              )}
            </article>
          ))}
          {workspace.deliveries.length === 0 && <p>No Discord delivery has been materialized yet.</p>}
        </div>
      </section>
    </main>
  );
}
