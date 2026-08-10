import Link from "next/link";

import { signOutAction } from "@/app/staff/actions";
import { StaffAccessDenied } from "@/components/staff-access-denied";
import { StaffNotice } from "@/components/staff-notice";
import { getDefaultLocale, readPublicSupabaseEnvironment } from "@/lib/env";
import { requireStaffSession } from "@/lib/staff-auth";
import { getStaffLicenses } from "@/lib/staff-licensing";

export const dynamic = "force-dynamic";

interface StaffLicensingPageProps {
  searchParams: Promise<{
    error?: string;
    notice?: string;
    q?: string;
  }>;
}

export default async function StaffLicensingPage({
  searchParams,
}: StaffLicensingPageProps) {
  const parameters = await searchParams;
  const search = parameters.q?.trim().slice(0, 100) || undefined;

  if (!readPublicSupabaseEnvironment()) {
    return (
      <main className="staff-main">
        <section className="notice-panel">
          <p className="eyebrow">Staff licensing unavailable</p>
          <h1>Supabase is not configured</h1>
          <p>No secondary data source is used when the registry is unavailable.</p>
        </section>
      </main>
    );
  }

  const { client } = await requireStaffSession();
  const result = await getStaffLicenses(client, search);
  if (!result.ok && result.code === "access_denied") {
    return (
      <main className="staff-main">
        <StaffAccessDenied />
      </main>
    );
  }
  if (!result.ok) {
    return (
      <main className="staff-main">
        <section className="notice-panel">
          <p className="eyebrow">Staff licensing unavailable</p>
          <h1>The licensing queue could not be loaded</h1>
          <p>No authoritative data was changed. Try again after the registry recovers.</p>
        </section>
      </main>
    );
  }

  const locale = getDefaultLocale();

  return (
    <main className="staff-main">
      <header className="staff-page-header">
        <div>
          <p className="eyebrow">Authenticated staff · licensing office</p>
          <h1>License work queue</h1>
          <p>
            Issue configured authority, manage modular endorsements, and record
            lifecycle decisions through audited Supabase commands.
          </p>
        </div>
        <div className="staff-button-row">
          <Link className="button button-secondary" href="/staff">
            Catalogue desk
          </Link>
          <Link className="button button-secondary" href="/staff/compliance">
            Compliance
          </Link>
          <Link className="button button-primary" href="/staff/licensing/new">
            Issue license
          </Link>
          <form action={signOutAction}>
            <button className="button button-secondary" type="submit">
              Sign out
            </button>
          </form>
        </div>
      </header>

      <StaffNotice error={parameters.error} notice={parameters.notice} />

      <form className="staff-search" method="get" role="search">
        <label className="field">
          <span>Search licenses</span>
          <input
            defaultValue={search}
            maxLength={100}
            name="q"
            placeholder="Reference, holder, or class"
            type="search"
          />
        </label>
        <button className="button button-primary" type="submit">
          Search
        </button>
        {search && (
          <Link className="button button-secondary" href="/staff/licensing">
            Clear
          </Link>
        )}
      </form>

      <p className="result-count">
        {result.data.length} license record{result.data.length === 1 ? "" : "s"}
      </p>

      <section className="staff-item-list" aria-label="License records">
        {result.data.map((license) => (
          <article className="staff-item-row" key={license.id}>
            <div className="staff-item-identity">
              <div className="staff-status-row">
                <span className={`staff-status staff-status-${license.status_code}`}>
                  {license.status_label}
                </span>
                <span>{license.license_class_label}</span>
              </div>
              <h2>{license.holder_name}</h2>
              <p>{license.public_reference}</p>
            </div>
            <dl className="staff-item-facts">
              <div>
                <dt>Jurisdiction</dt>
                <dd>{license.jurisdiction_label}</dd>
              </div>
              <div>
                <dt>Dealer authority</dt>
                <dd>{license.dealer_reference ?? "Not linked"}</dd>
              </div>
              <div>
                <dt>Endorsements</dt>
                <dd>{license.endorsements.filter((item) => !item.revoked_at).length}</dd>
              </div>
              <div>
                <dt>Last update</dt>
                <dd>{new Date(license.updated_at).toLocaleString(locale)}</dd>
              </div>
            </dl>
            <Link
              className="button button-secondary"
              href={`/staff/licensing/${license.id}`}
            >
              Review license
            </Link>
          </article>
        ))}
      </section>

      {result.data.length === 0 && (
        <section className="empty-state">
          <p className="eyebrow">No licenses found</p>
          <h2>The queue is clear</h2>
          <p>Try another search or issue a new configured license.</p>
        </section>
      )}
    </main>
  );
}
