import Link from "next/link";

import { StaffAccessDenied } from "@/components/staff-access-denied";
import { StaffNotice } from "@/components/staff-notice";
import { getDefaultLocale, readPublicSupabaseEnvironment } from "@/lib/env";
import { requireStaffSession } from "@/lib/staff-auth";
import { getStaffDealers } from "@/lib/staff-dealers";

export const dynamic = "force-dynamic";

export default async function StaffDealersPage({ searchParams }: { searchParams: Promise<{ error?: string; notice?: string; q?: string }> }) {
  const parameters = await searchParams;
  const search = parameters.q?.trim().slice(0, 100) || undefined;
  if (!readPublicSupabaseEnvironment()) return <main className="staff-main"><section className="notice-panel"><p className="eyebrow">Customer records unavailable</p><h1>Supabase is not configured</h1><p>No secondary data source is used.</p></section></main>;
  const { client } = await requireStaffSession();
  const result = await getStaffDealers(client, search);
  if (!result.ok && result.code === "access_denied") return <main className="staff-main"><StaffAccessDenied /></main>;
  if (!result.ok) return <main className="staff-main"><section className="notice-panel"><p className="eyebrow">Customer records unavailable</p><h1>The customer list could not be loaded</h1><p>No authoritative data was changed.</p></section></main>;
  const locale = getDefaultLocale();

  return <main className="staff-main">
    <header className="staff-page-header"><div><p className="eyebrow">Businesses and customers</p><h1>Customers</h1><p>Find a licensed business, inspect its authority, or add a new business account.</p></div><div className="staff-button-row">
      <Link className="button button-primary" href="/staff/dealers/new">Add business</Link>
    </div></header>
    <StaffNotice error={parameters.error} notice={parameters.notice} />
    <form className="staff-search" method="get" role="search"><label className="field"><span>Find a customer</span><input defaultValue={search} maxLength={100} name="q" placeholder="Business name or reference" type="search" /></label><button className="button button-primary" type="submit">Search</button>{search && <Link className="button button-secondary" href="/staff/dealers">Clear</Link>}</form>
    <p className="result-count">{result.data.length} business account{result.data.length === 1 ? "" : "s"}</p>
    <section className="staff-item-list" aria-label="Dealer authorizations">{result.data.map((dealer) => <article className="staff-item-row" key={dealer.id}>
      <div className="staff-item-identity"><div className="staff-status-row"><span className={`staff-status staff-status-${dealer.status_code}`}>{dealer.status_label}</span><span>{dealer.dealer_type_label}</span></div><h2>{dealer.display_name}</h2><p>{dealer.public_reference}</p></div>
      <dl className="staff-item-facts"><div><dt>Jurisdiction</dt><dd>{dealer.jurisdiction_label}</dd></div><div><dt>Public record</dt><dd>{dealer.public_disclosure_enabled ? "Enabled" : "Private"}</dd></div><div><dt>Premises</dt><dd>{dealer.approved_premises_public ?? "Not listed"}</dd></div><div><dt>Last update</dt><dd>{new Date(dealer.updated_at).toLocaleString(locale)}</dd></div></dl>
      <Link className="button button-secondary" href={`/staff/dealers/${dealer.id}`}>Open customer</Link>
    </article>)}</section>
    {result.data.length === 0 && <section className="empty-state"><p className="eyebrow">No customers found</p><h2>Try another name</h2><p>Or add a new business account.</p></section>}
  </main>;
}
