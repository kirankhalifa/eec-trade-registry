import Link from "next/link";

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
          <p className="eyebrow">Catalogue unavailable</p>
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
          <p className="eyebrow">Catalogue unavailable</p>
          <h1>The catalogue could not be loaded</h1>
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
          <p className="eyebrow">Goods and materials</p>
          <h1>Catalogue</h1>
          <p>Add or update what the Company buys and sells. Each item keeps its public listing, price, supply policy, and stock history together.</p>
        </div>
        <div className="staff-button-row">
          <Link className="button button-primary" href="/staff/configuration#quick-add-item">
            Add item
          </Link>
        </div>
      </header>

      <StaffNotice error={parameters.error} notice={parameters.notice} />

      <form className="staff-search" method="get" role="search">
        <label className="field">
          <span>Find an item</span>
          <input
            defaultValue={search}
            maxLength={100}
            name="q"
            placeholder="Item name or code"
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
        {result.data.length} item{result.data.length === 1 ? "" : "s"}
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
                <dt>Public listing</dt>
                <dd>{item.public_name ? "Published" : "Not published"}</dd>
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
                <dt>Last changed</dt>
                <dd>{new Date(item.updated_at).toLocaleString(locale)}</dd>
              </div>
            </dl>
            <Link
              className="button button-secondary"
              href={`/staff/items/${item.id}/edit`}
            >
              Open item
            </Link>
          </article>
        ))}
      </section>

      {result.data.length === 0 && (
        <section className="empty-state">
          <p className="eyebrow">No items found</p>
          <h2>Try another name</h2>
        </section>
      )}
    </main>
  );
}
