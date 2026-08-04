import Link from "next/link";

import { signOutAction } from "@/app/staff/actions";
import { StaffAccessDenied } from "@/components/staff-access-denied";
import { StaffNotice } from "@/components/staff-notice";
import { getDefaultLocale, readPublicSupabaseEnvironment } from "@/lib/env";
import { requireStaffSession } from "@/lib/staff-auth";
import { getStaffCatalogueItems } from "@/lib/staff-catalogue";

export const dynamic = "force-dynamic";

interface StaffCataloguePageProps {
  searchParams: Promise<{
    error?: string;
    notice?: string;
    q?: string;
  }>;
}

export default async function StaffCataloguePage({
  searchParams,
}: StaffCataloguePageProps) {
  const parameters = await searchParams;
  const search = parameters.q?.trim().slice(0, 100) || undefined;

  if (!readPublicSupabaseEnvironment()) {
    return (
      <main className="staff-main">
        <section className="notice-panel">
          <p className="eyebrow">Staff catalogue unavailable</p>
          <h1>Supabase is not configured</h1>
          <p>No secondary data source is used when the registry is unavailable.</p>
        </section>
      </main>
    );
  }

  const { client } = await requireStaffSession();
  const result = await getStaffCatalogueItems(client, search);
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
          <p className="eyebrow">Staff catalogue unavailable</p>
          <h1>The work queue could not be loaded</h1>
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
          <p className="eyebrow">Authenticated staff · catalogue management</p>
          <h1>Canonical item work queue</h1>
          <p>
            Maintain internal source records. Publication and price changes are
            visible for context but remain read-only until their policies are approved.
          </p>
        </div>
        <div className="staff-button-row">
          <Link className="button button-secondary" href="/staff/orders">
            Order desk
          </Link>
          <Link className="button button-secondary" href="/staff/inventory">
            Inventory desk
          </Link>
          <Link className="button button-secondary" href="/staff/licensing">
            Licensing office
          </Link>
          <Link className="button button-primary" href="/staff/items/new">
            New canonical item
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
          <span>Search internal catalogue</span>
          <input
            defaultValue={search}
            maxLength={100}
            name="q"
            placeholder="Item code, source name, or slug"
            type="search"
          />
        </label>
        <button className="button button-primary" type="submit">
          Search
        </button>
        {search && (
          <Link className="button button-secondary" href="/staff">
            Clear
          </Link>
        )}
      </form>

      <p className="result-count">
        {result.data.length} internal record{result.data.length === 1 ? "" : "s"}
      </p>

      <section className="staff-item-list" aria-label="Canonical catalogue records">
        {result.data.map((item) => (
          <article className="staff-item-row" key={item.id}>
            <div className="staff-item-identity">
              <div className="staff-status-row">
                <span className={`staff-status staff-status-${item.status}`}>
                  {item.status}
                </span>
                <span>{item.category_name}</span>
              </div>
              <h2>{item.display_name}</h2>
              <p>
                {item.item_code} · /{item.slug}
              </p>
            </div>
            <dl className="staff-item-facts">
              <div>
                <dt>Public presentation</dt>
                <dd>{item.public_name ?? "Not published"}</dd>
              </div>
              <div>
                <dt>Publication state</dt>
                <dd>{item.publication_status ?? "None"}</dd>
              </div>
              <div>
                <dt>Public price</dt>
                <dd>
                  {item.price_amount_minor === null
                    ? "Not configured"
                    : `${item.currency_code ?? "Currency"} · configured`}
                </dd>
              </div>
              <div>
                <dt>Last source update</dt>
                <dd>{new Date(item.updated_at).toLocaleString(locale)}</dd>
              </div>
            </dl>
            <Link
              className="button button-secondary"
              href={`/staff/items/${item.id}/edit`}
            >
              Review record
            </Link>
          </article>
        ))}
      </section>

      {result.data.length === 0 && (
        <section className="empty-state">
          <p className="eyebrow">No internal records found</p>
          <h2>Try another search</h2>
          <p>The query is evaluated by the authorized Supabase projection.</p>
        </section>
      )}
    </main>
  );
}
