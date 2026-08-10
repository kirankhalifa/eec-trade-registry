import Link from "next/link";

import { signOutDealerAction } from "@/app/dealer/actions";
import { DealerAccessDenied } from "@/components/dealer-access-denied";
import { requireDealerSession } from "@/lib/dealer-auth";
import { getDealerPortalOverview } from "@/lib/dealer-portal";
import { getDefaultLocale, readPublicSupabaseEnvironment } from "@/lib/env";

export const dynamic = "force-dynamic";

function formatDate(value: string, locale: string): string {
  return new Intl.DateTimeFormat(locale, { dateStyle: "medium" }).format(
    new Date(value),
  );
}

export default async function DealerPortalPage() {
  if (!readPublicSupabaseEnvironment()) {
    return (
      <main className="dealer-main">
        <section className="notice-panel">
          <p className="eyebrow">Dealer portal unavailable</p>
          <h1>Supabase is not configured</h1>
          <p>No secondary data source is used when the registry is unavailable.</p>
        </section>
      </main>
    );
  }

  const { client } = await requireDealerSession();
  const result = await getDealerPortalOverview(client);
  if (!result.ok && result.code === "access_denied") {
    return (
      <main className="dealer-main">
        <DealerAccessDenied />
      </main>
    );
  }
  if (!result.ok) {
    return (
      <main className="dealer-main">
        <section className="notice-panel">
          <p className="eyebrow">Dealer portal unavailable</p>
          <h1>The private registry overview could not be loaded</h1>
          <p>No cached or public record has been substituted.</p>
        </section>
      </main>
    );
  }

  const locale = getDefaultLocale();

  return (
    <main className="dealer-main">
      <header className="dealer-page-header">
        <div>
          <p className="eyebrow">Authenticated representative</p>
          <h1>Organization registry overview</h1>
          <p>
            Signed in as {result.data.actor_display_name}. This view is resolved
            from current party representation, dealer authorization, licenses,
            endorsements, and public conditions in Supabase.
          </p>
        </div>
        <div className="staff-button-row">
          <Link className="button button-primary" href="/dealer/orders">
            Wholesale orders
          </Link>
          <Link className="button button-secondary" href="/dealer/consignments">
            Consigned stock
          </Link>
          <Link className="button button-secondary" href="/">
            Public catalogue
          </Link>
          <form action={signOutDealerAction}>
            <button className="button button-primary" type="submit">
              Sign out
            </button>
          </form>
        </div>
      </header>

      <p className="dealer-generated-at">
        Registry queried {new Date(result.data.generated_at).toLocaleString(locale)}
      </p>

      <div className="dealer-organization-list">
        {result.data.representations.map((representation) => (
          <article className="dealer-organization" key={representation.representation_id}>
            <header>
              <div>
                <p className="eyebrow">Represented organization</p>
                <h2>{representation.party_name}</h2>
                <p>
                  {representation.role_label}
                  {representation.jurisdiction_label
                    ? ` · ${representation.jurisdiction_label}`
                    : ""}
                </p>
              </div>
              <span className="dealer-private-label">Private view</span>
            </header>

            <section className="dealer-record-section" aria-label="Dealer authorizations">
              <div className="dealer-section-heading">
                <h3>Dealer authorizations</h3>
                <span>{representation.dealer_authorizations.length}</span>
              </div>
              <div className="dealer-record-grid">
                {representation.dealer_authorizations.map((authorization) => (
                  <article
                    className="dealer-record-card"
                    key={authorization.public_reference}
                  >
                    <div className="dealer-record-status">
                      <span
                        className={
                          authorization.is_currently_authorized
                            ? "dealer-status-current"
                            : "dealer-status-inactive"
                        }
                      >
                        {authorization.status_label}
                      </span>
                      <strong>{authorization.public_reference}</strong>
                    </div>
                    <h4>{authorization.dealer_type_label}</h4>
                    <dl>
                      <div>
                        <dt>Effective</dt>
                        <dd>{formatDate(authorization.effective_from, locale)}</dd>
                      </div>
                      <div>
                        <dt>Ends</dt>
                        <dd>
                          {authorization.effective_until
                            ? formatDate(authorization.effective_until, locale)
                            : "No recorded end"}
                        </dd>
                      </div>
                      <div>
                        <dt>Premises</dt>
                        <dd>{authorization.premises_label ?? "Not specified"}</dd>
                      </div>
                    </dl>
                    {authorization.notice && <p>{authorization.notice}</p>}
                  </article>
                ))}
              </div>
            </section>

            <section className="dealer-record-section" aria-label="Licenses">
              <div className="dealer-section-heading">
                <h3>Licenses and endorsements</h3>
                <span>{representation.licenses.length}</span>
              </div>
              {representation.licenses.length === 0 ? (
                <p className="dealer-empty-records">
                  No licenses are recorded for this represented organization.
                </p>
              ) : (
                <div className="dealer-license-list">
                  {representation.licenses.map((license) => (
                    <article className="dealer-license-row" key={license.public_reference}>
                      <div className="dealer-license-identity">
                        <span
                          className={
                            license.is_currently_authorized
                              ? "dealer-status-current"
                              : "dealer-status-inactive"
                          }
                        >
                          {license.status_label}
                        </span>
                        <h4>{license.license_class_label}</h4>
                        <p>{license.public_reference}</p>
                      </div>
                      <dl>
                        <div>
                          <dt>Jurisdiction</dt>
                          <dd>{license.jurisdiction_label}</dd>
                        </div>
                        <div>
                          <dt>Effective</dt>
                          <dd>{formatDate(license.effective_from, locale)}</dd>
                        </div>
                        <div>
                          <dt>Expires</dt>
                          <dd>
                            {license.expires_at
                              ? formatDate(license.expires_at, locale)
                              : "No recorded expiration"}
                          </dd>
                        </div>
                      </dl>
                      <div className="dealer-license-details">
                        <div>
                          <strong>Current endorsements</strong>
                          {license.endorsements.length > 0 ? (
                            <ul>
                              {license.endorsements.map((endorsement) => (
                                <li key={endorsement.label}>{endorsement.label}</li>
                              ))}
                            </ul>
                          ) : (
                            <p>None recorded</p>
                          )}
                        </div>
                        <div>
                          <strong>Published conditions</strong>
                          {license.public_conditions.length > 0 ? (
                            <ul>
                              {license.public_conditions.map((condition) => (
                                <li key={condition}>{condition}</li>
                              ))}
                            </ul>
                          ) : (
                            <p>None recorded</p>
                          )}
                        </div>
                      </div>
                    </article>
                  ))}
                </div>
              )}
            </section>
          </article>
        ))}
      </div>

      <aside className="dealer-policy-note">
        <strong>Registry access only</strong>
        <p>
          Ordering, private pricing, quotas, stock reservations, and transaction
          approvals are not enabled in this foundation and are never calculated
          by this page.
        </p>
      </aside>
    </main>
  );
}
