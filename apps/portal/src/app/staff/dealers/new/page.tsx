import Link from "next/link";

import { createDealerAction } from "@/app/staff/dealers/actions";
import { StaffAccessDenied } from "@/components/staff-access-denied";
import { StaffNotice } from "@/components/staff-notice";
import { requireStaffSession } from "@/lib/staff-auth";
import { getStaffDealerReferenceData } from "@/lib/staff-dealers";

export const dynamic = "force-dynamic";

export default async function NewDealerPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const parameters = await searchParams;
  const { client } = await requireStaffSession();
  const result = await getStaffDealerReferenceData(client);
  if (!result.ok && result.code === "access_denied") return <main className="staff-main"><StaffAccessDenied /></main>;
  if (!result.ok) return <main className="staff-main"><section className="notice-panel"><h1>Dealer onboarding is unavailable</h1><p>No authoritative data was changed.</p></section></main>;
  const references = result.data;

  return <main className="staff-main">
    <header className="staff-page-header"><div><p className="eyebrow">Dealer registry · audited onboarding</p><h1>Onboard a dealer</h1><p>Create the party and its first authorization in one database transaction.</p></div><Link className="button button-secondary" href="/staff/dealers">Back to dealers</Link></header>
    <StaffNotice error={parameters.error} />
    <form action={createDealerAction} className="staff-form">
      <section className="form-section"><div><p className="eyebrow">Party identity</p><h2>Counterparty</h2></div><div className="form-grid">
        <label className="field"><span>Party type</span><select defaultValue="organization" name="party_type_code" required>{references.party_types.map((option) => <option key={option.code} value={option.code}>{option.display_name}</option>)}</select></label>
        <label className="field"><span>Legal name</span><input maxLength={200} name="legal_name" required /></label>
        <label className="field"><span>Internal display name</span><input maxLength={200} name="display_name" required /></label>
        <label className="field"><span>Public display name</span><input maxLength={200} name="public_display_name" /></label>
      </div></section>
      <section className="form-section"><div><p className="eyebrow">Authority</p><h2>Initial authorization</h2></div><div className="form-grid">
        <label className="field"><span>Dealer type</span><select name="dealer_type_code" required>{references.dealer_types.map((option) => <option key={option.code} value={option.code}>{option.display_name}</option>)}</select></label>
        <label className="field"><span>Jurisdiction</span><select name="jurisdiction_code" required>{references.jurisdictions.map((option) => <option key={option.code} value={option.code}>{option.display_name}</option>)}</select></label>
        <label className="field"><span>Initial status</span><select defaultValue="internal-review" name="initial_status_code" required>{references.initial_statuses.map((option) => <option key={option.code} value={option.code}>{option.display_name}</option>)}</select></label>
        <label className="field field-full"><span>Public premises</span><input maxLength={1000} name="approved_premises_public" /></label>
        <label className="field field-full"><span>Public notes</span><textarea maxLength={1000} name="public_notes" rows={3} /></label>
        <label className="field field-full"><span>Private notes</span><textarea maxLength={4000} name="private_notes" rows={4} /></label>
        <label className="checkbox-field"><input name="public_disclosure_enabled" type="checkbox" /><span>Publish this authorization in verification and exports</span></label>
        <label className="field field-full"><span>Audit reason</span><textarea maxLength={500} name="reason" required rows={3} /></label>
      </div></section>
      <div className="staff-button-row"><button className="button button-primary" type="submit">Create dealer authorization</button><Link className="button button-secondary" href="/staff/dealers">Cancel</Link></div>
    </form>
  </main>;
}
