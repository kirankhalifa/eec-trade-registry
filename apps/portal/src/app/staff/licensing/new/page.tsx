import Link from "next/link";

import { issueLicenseAction } from "@/app/staff/licensing/actions";
import { StaffAccessDenied } from "@/components/staff-access-denied";
import { StaffNotice } from "@/components/staff-notice";
import { requireStaffSession } from "@/lib/staff-auth";
import { getStaffLicensingReferenceData } from "@/lib/staff-licensing";

interface NewLicensePageProps {
  searchParams: Promise<{ error?: string; notice?: string }>;
}

export default async function NewLicensePage({ searchParams }: NewLicensePageProps) {
  const parameters = await searchParams;
  const { client } = await requireStaffSession();
  const references = await getStaffLicensingReferenceData(client);

  if (!references.ok && references.code === "access_denied") {
    return (
      <main className="staff-editor-main staff-main">
        <StaffAccessDenied />
      </main>
    );
  }
  if (!references.ok) {
    return (
      <main className="staff-editor-main staff-main">
        <section className="notice-panel">
          <p className="eyebrow">Licensing configuration unavailable</p>
          <h1>The issue form could not be loaded</h1>
          <p>No authoritative data was changed.</p>
        </section>
      </main>
    );
  }

  return (
    <main className="staff-editor-main staff-main">
      <Link className="back-link" href="/staff/licensing">
        ← Back to licensing queue
      </Link>
      <header className="staff-editor-header">
        <p className="eyebrow">Licensing office · new authority</p>
        <h1>Issue license</h1>
        <p>
          References are allocated transactionally. The initial term is open-ended
          because duration and renewal policy remain unresolved.
        </p>
      </header>

      <StaffNotice error={parameters.error} notice={parameters.notice} />

      <form action={issueLicenseAction} className="staff-form">
        <fieldset className="staff-fieldset">
          <legend>Holder and authority</legend>
          <div className="staff-form-grid">
            <label className="field">
              <span>Holder</span>
              <select name="holder_party_id" required>
                <option value="">Select a party</option>
                {references.data.parties.map((party) => (
                  <option key={party.id} value={party.id}>
                    {party.display_name} · {party.party_type}
                  </option>
                ))}
              </select>
            </label>
            <label className="field">
              <span>Dealer authorization (optional)</span>
              <select name="dealer_authorization_id">
                <option value="">No linked dealer authorization</option>
                {references.data.dealer_authorizations.map((dealer) => (
                  <option key={dealer.id} value={dealer.id}>
                    {dealer.public_reference}
                  </option>
                ))}
              </select>
            </label>
            <label className="field">
              <span>License class</span>
              <select name="license_class_code" required>
                {references.data.license_classes.map((option) => (
                  <option key={option.code} value={option.code}>
                    {option.display_name}
                  </option>
                ))}
              </select>
            </label>
            <label className="field">
              <span>Jurisdiction</span>
              <select name="jurisdiction_code" required>
                {references.data.jurisdictions.map((option) => (
                  <option key={option.code} value={option.code}>
                    {option.display_name}
                  </option>
                ))}
              </select>
            </label>
            <label className="field">
              <span>Initial status</span>
              <select name="initial_status_code" required>
                {references.data.initial_statuses.map((option) => (
                  <option key={option.code} value={option.code}>
                    {option.display_name}
                  </option>
                ))}
              </select>
            </label>
            <label className="staff-checkbox-field">
              <input name="public_disclosure_enabled" type="checkbox" />
              <span>Allow exact-reference public verification</span>
            </label>
          </div>
        </fieldset>

        <fieldset className="staff-fieldset">
          <legend>Initial endorsements</legend>
          <div className="staff-checkbox-grid">
            {references.data.endorsements.map((endorsement) => (
              <label className="staff-checkbox-field" key={endorsement.code}>
                <input
                  name="endorsement_codes"
                  type="checkbox"
                  value={endorsement.code}
                />
                <span>{endorsement.display_name}</span>
              </label>
            ))}
          </div>
        </fieldset>

        <fieldset className="staff-fieldset">
          <legend>Disclosure and internal record</legend>
          <div className="staff-form-grid">
            <label className="field staff-field-wide">
              <span>Public notice</span>
              <textarea maxLength={1000} name="public_notes" rows={3} />
            </label>
            <label className="field staff-field-wide">
              <span>Private licensing notes</span>
              <textarea maxLength={4000} name="private_notes" rows={5} />
            </label>
          </div>
        </fieldset>

        <fieldset className="staff-fieldset staff-audit-fieldset">
          <legend>Audit reason</legend>
          <label className="field">
            <span>Why is this license being issued?</span>
            <textarea maxLength={500} minLength={1} name="reason" required rows={3} />
          </label>
        </fieldset>

        <div className="staff-button-row">
          <button className="button button-primary" type="submit">
            Issue license
          </button>
          <Link className="button button-secondary" href="/staff/licensing">
            Cancel
          </Link>
        </div>
      </form>
    </main>
  );
}
