import Link from "next/link";
import { notFound } from "next/navigation";
import { z } from "zod";

import {
  changeLicenseStatusAction,
  grantLicenseEndorsementAction,
  revokeLicenseEndorsementAction,
} from "@/app/staff/licensing/actions";
import { ReferenceBlock } from "@/components/reference-block";
import { StaffAccessDenied } from "@/components/staff-access-denied";
import { StaffNotice } from "@/components/staff-notice";
import { getDefaultLocale } from "@/lib/env";
import { requireStaffSession } from "@/lib/staff-auth";
import {
  getStaffLicense,
  getStaffLicensingReferenceData,
} from "@/lib/staff-licensing";

interface LicenseDetailPageProps {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ error?: string; notice?: string }>;
}

const allowedTargets: Record<string, string[]> = {
  active: ["suspended", "revoked", "surrendered"],
  provisional: ["active", "suspended", "revoked", "surrendered"],
  suspended: ["active", "revoked", "surrendered"],
};

const statusLabels: Record<string, string> = {
  active: "Activate / reinstate",
  revoked: "Revoke permanently",
  surrendered: "Record surrender",
  suspended: "Suspend",
};

export default async function LicenseDetailPage({
  params,
  searchParams,
}: LicenseDetailPageProps) {
  const [{ id }, parameters] = await Promise.all([params, searchParams]);
  if (!z.guid().safeParse(id).success) {
    notFound();
  }

  const { client } = await requireStaffSession();
  const [licenseResult, referenceResult] = await Promise.all([
    getStaffLicense(client, id),
    getStaffLicensingReferenceData(client),
  ]);
  if (
    (!licenseResult.ok && licenseResult.code === "access_denied") ||
    (!referenceResult.ok && referenceResult.code === "access_denied")
  ) {
    return (
      <main className="staff-editor-main staff-main">
        <StaffAccessDenied />
      </main>
    );
  }
  if (!licenseResult.ok || !referenceResult.ok) {
    return (
      <main className="staff-editor-main staff-main">
        <section className="notice-panel">
          <p className="eyebrow">License record unavailable</p>
          <h1>The licensing record could not be loaded</h1>
          <p>No authoritative data was changed.</p>
        </section>
      </main>
    );
  }
  if (!licenseResult.data) {
    notFound();
  }

  const license = licenseResult.data;
  const locale = getDefaultLocale();
  const activeEndorsementCodes = new Set(
    license.endorsements
      .filter((endorsement) => !endorsement.revoked_at)
      .map((endorsement) => endorsement.code),
  );
  const availableEndorsements = referenceResult.data.endorsements.filter(
    (option) => !activeEndorsementCodes.has(option.code),
  );
  const targets = allowedTargets[license.status_code] ?? [];

  return (
    <main className="staff-editor-main staff-main">
      <Link className="back-link" href="/staff/licensing">
        ← Back to licensing queue
      </Link>
      <header className="staff-editor-header">
        <p className="eyebrow">Licensing office · {license.status_label}</p>
        <h1>{license.holder_name}</h1>
        <p>
          {license.public_reference} · {license.license_class_label}
        </p>
      </header>

      <ReferenceBlock label="License reference" reference={license.public_reference} status={license.status_label} />

      <StaffNotice error={parameters.error} notice={parameters.notice} />

      <section className="staff-readonly-grid" aria-label="License summary">
        <div>
          <span>Jurisdiction</span>
          <strong>{license.jurisdiction_label}</strong>
        </div>
        <div>
          <span>Effective</span>
          <strong>{new Date(license.effective_from).toLocaleString(locale)}</strong>
        </div>
        <div>
          <span>Expiration</span>
          <strong>
            {license.expires_at
              ? new Date(license.expires_at).toLocaleString(locale)
              : "Open term"}
          </strong>
        </div>
      </section>

      <section className="staff-license-section">
        <div className="staff-license-section-heading">
          <div>
            <p className="eyebrow">Modular authority</p>
            <h2>Endorsements</h2>
          </div>
          <span>{activeEndorsementCodes.size} active</span>
        </div>

        <div className="staff-license-endorsements">
          {license.endorsements.map((endorsement) => (
            <article className="staff-license-endorsement" key={endorsement.id}>
              <div>
                <h3>{endorsement.label}</h3>
                <p>
                  {endorsement.revoked_at
                    ? `Revoked ${new Date(endorsement.revoked_at).toLocaleString(locale)}`
                    : endorsement.public_disclosure_enabled
                      ? "Visible in public verification"
                      : "Private to authorized users"}
                </p>
              </div>
              {!endorsement.revoked_at && (
                <form action={revokeLicenseEndorsementAction} className="staff-inline-action">
                  <input name="license_id" type="hidden" value={license.id} />
                  <input
                    name="license_endorsement_id"
                    type="hidden"
                    value={endorsement.id}
                  />
                  <input
                    name="expected_license_version"
                    type="hidden"
                    value={license.version}
                  />
                  <label className="field">
                    <span>Revocation reason</span>
                    <input maxLength={500} minLength={1} name="reason" required />
                  </label>
                  <button className="button button-secondary" type="submit">
                    Revoke endorsement
                  </button>
                </form>
              )}
            </article>
          ))}
          {license.endorsements.length === 0 && (
            <p className="dealer-empty-records">No endorsements have been recorded.</p>
          )}
        </div>

        {availableEndorsements.length > 0 && !["revoked", "surrendered", "expired"].includes(license.status_code) && (
          <form action={grantLicenseEndorsementAction} className="staff-form staff-license-action-form">
            <input name="license_id" type="hidden" value={license.id} />
            <input
              name="expected_license_version"
              type="hidden"
              value={license.version}
            />
            <label className="field">
              <span>Endorsement</span>
              <select name="endorsement_code" required>
                {availableEndorsements.map((option) => (
                  <option key={option.code} value={option.code}>
                    {option.display_name}
                  </option>
                ))}
              </select>
            </label>
            <label className="staff-checkbox-field">
              <input name="public_disclosure_enabled" type="checkbox" />
              <span>Show in public verification</span>
            </label>
            <label className="field">
              <span>Grant reason</span>
              <input maxLength={500} minLength={1} name="reason" required />
            </label>
            <button className="button button-primary" type="submit">
              Grant endorsement
            </button>
          </form>
        )}
      </section>

      <section className="staff-license-section">
        <div className="staff-license-section-heading">
          <div>
            <p className="eyebrow">Consequential command</p>
            <h2>License status</h2>
          </div>
          <span>Version {license.version}</span>
        </div>
        {targets.length > 0 ? (
          <form action={changeLicenseStatusAction} className="staff-form staff-license-action-form">
            <input name="license_id" type="hidden" value={license.id} />
            <input name="expected_version" type="hidden" value={license.version} />
            <label className="field">
              <span>New status</span>
              <select name="target_status_code" required>
                {targets.map((target) => (
                  <option key={target} value={target}>
                    {statusLabels[target] ?? target}
                  </option>
                ))}
              </select>
            </label>
            <label className="field">
              <span>Decision reason</span>
              <textarea maxLength={500} minLength={1} name="reason" required rows={3} />
            </label>
            <button className="button button-primary" type="submit">
              Record status decision
            </button>
          </form>
        ) : (
          <p className="dealer-empty-records">
            This status is terminal. History remains available and cannot be rewritten.
          </p>
        )}
      </section>

      <section className="staff-license-section">
        <div className="staff-license-section-heading">
          <div>
            <p className="eyebrow">Record visibility</p>
            <h2>Notes</h2>
          </div>
          <span>{license.public_disclosure_enabled ? "Public lookup enabled" : "Private"}</span>
        </div>
        <dl className="staff-license-notes">
          <div>
            <dt>Public notice</dt>
            <dd>{license.public_notes || "None"}</dd>
          </div>
          <div>
            <dt>Private licensing note</dt>
            <dd>{license.private_notes || "None"}</dd>
          </div>
        </dl>
      </section>
    </main>
  );
}
