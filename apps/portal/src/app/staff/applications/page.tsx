import Link from "next/link";

import { reviewLicenseApplicationAction } from "@/app/staff/applications/actions";
import { signOutAction } from "@/app/staff/actions";
import { StaffAccessDenied } from "@/components/staff-access-denied";
import { StaffNotice } from "@/components/staff-notice";
import { getDefaultLocale } from "@/lib/env";
import { getLicenseApplicationReviewWorkspace, type LicenseApplicationReviewWorkspace } from "@/lib/license-application-review";
import { requireStaffSession } from "@/lib/staff-auth";

export const dynamic = "force-dynamic";

interface ApplicationsPageProps { searchParams: Promise<{ error?: string; notice?: string }> }
type Application = LicenseApplicationReviewWorkspace["applications"][number];

function ApplicationFacts({ application, locale }: { application: Application; locale: string }) {
  return <>
    <dl className="staff-item-facts">
      <div><dt>Requested authority</dt><dd>{application.class_name}</dd></div>
      <div><dt>Jurisdiction</dt><dd>{application.jurisdiction_name}</dd></div>
      <div><dt>Contact</dt><dd>{application.contact_label}</dd></div>
      <div><dt>Submitted</dt><dd>{new Date(application.submitted_at).toLocaleString(locale)}</dd></div>
      {application.existing_license_reference && <div><dt>Existing license</dt><dd>{application.existing_license_reference}</dd></div>}
      {application.issued_license_reference && <div><dt>Resulting license</dt><dd>{application.issued_license_reference}</dd></div>}
    </dl>
    <div><strong>Requested endorsements</strong><p>{application.requested_endorsements.length > 0 ? application.requested_endorsements.map((item) => item.label).join(", ") : "None"}</p></div>
    <div><strong>Applicant statement</strong><p>{application.statement}</p></div>
  </>;
}

export default async function StaffApplicationsPage({ searchParams }: ApplicationsPageProps) {
  const parameters = await searchParams;
  const { client } = await requireStaffSession();
  const result = await getLicenseApplicationReviewWorkspace(client);
  if (!result.ok && result.denied) return <main className="staff-main"><StaffAccessDenied /></main>;
  if (!result.ok) return <main className="staff-main"><section className="notice-panel"><h1>Application queue unavailable</h1><p>No decision was recorded and no fallback source was used.</p></section></main>;

  const locale = getDefaultLocale();
  const pending = result.data.applications.filter((application) => application.status === "submitted" || application.status === "under_review");
  const recent = result.data.applications.filter((application) => application.status !== "submitted" && application.status !== "under_review");

  return <main className="staff-main">
    <header className="staff-page-header"><div><p className="eyebrow">Licensing office · review queue</p><h1>License applications</h1><p>Review every public application, requested endorsement, and renewal before issuing or denying authority.</p></div><div className="staff-button-row"><Link className="button button-primary" href="/staff/dashboard">Dashboard</Link><Link className="button button-secondary" href="/staff/dealers/new">Onboard a business</Link><Link className="button button-secondary" href="/staff/licensing">License registry</Link><Link className="button button-secondary" href="/apply">Public form</Link><form action={signOutAction}><button className="button button-secondary">Sign out</button></form></div></header>
    <StaffNotice error={parameters.error} notice={parameters.notice}/>

    <section className="inventory-summary"><article><span>Awaiting decision</span><strong>{pending.length}</strong></article><article><span>Reviewed in 90 days</span><strong>{recent.length}</strong></article></section>

    <section className="notice-panel"><h2>Before approving a new business license</h2><p>The applicant must already exist as a canonical party. If they are a licensed business, use <Link href="/staff/dealers/new">Onboard a business</Link> first, then return here and choose that holder. Renewal applications already point to their existing license.</p></section>

    <section className="integration-section"><div className="inventory-section-heading"><div><p className="eyebrow">Action required</p><h2>Pending applications</h2></div><p>Approval issues or renews authority atomically; denial records the decision without creating a license.</p></div><div className="inventory-reservation-list">
      {pending.map((application) => <article className="inventory-reservation-card" key={application.id}><header><div><span className="order-status order-status-submitted">{application.type}</span><h3>{application.reference} · {application.applicant_name}</h3></div><strong>v{application.version}</strong></header><ApplicationFacts application={application} locale={locale}/><form action={reviewLicenseApplicationAction} className="inventory-command-form"><input name="application_id" type="hidden" value={application.id}/><input name="expected_version" type="hidden" value={application.version}/><div className="staff-form-grid"><label className="field"><span>Decision</span><select name="decision"><option value="approve">Approve and issue / renew</option><option value="deny">Deny application</option></select></label><label className="field"><span>Canonical holder (new application)</span><select name="holder_party_id"><option value="">Required only for approval of a new license</option>{result.data.parties.map((party) => <option key={party.id} value={party.id}>{party.name} · {party.type}</option>)}</select></label></div><div className="staff-form-grid"><label className="field"><span>Effective from</span><input name="effective_from" type="datetime-local"/></label><label className="field"><span>Expires at</span><input name="expires_at" type="datetime-local"/></label></div><label className="field"><span>Initial license status</span><select name="initial_status_code"><option value="active">Active</option><option value="provisional">Provisional</option></select></label><label className="field"><span>Decision reason</span><input maxLength={500} name="reason" placeholder="Evidence checked and reason for this decision" required/></label><button className="button button-primary">Record final decision</button></form></article>)}
      {pending.length === 0 && <p>No application is waiting for review.</p>}
    </div></section>

    {recent.length > 0 && <section className="integration-section"><div className="inventory-section-heading"><div><p className="eyebrow">Recent evidence</p><h2>Reviewed applications</h2></div></div><div className="inventory-reservation-list">{recent.map((application) => <article className="inventory-reservation-card" key={application.id}><header><div><span className={`staff-status staff-status-${application.status === "denied" ? "inactive" : "active"}`}>{application.status}</span><h3>{application.reference} · {application.applicant_name}</h3></div></header><ApplicationFacts application={application} locale={locale}/>{application.reviewed_at && <p>Reviewed {new Date(application.reviewed_at).toLocaleString(locale)}</p>}{application.review_reason && <p><strong>Decision reason:</strong> {application.review_reason}</p>}</article>)}</div></section>}
  </main>;
}
