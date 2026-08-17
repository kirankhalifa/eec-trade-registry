import Link from "next/link";
import { notFound } from "next/navigation";
import { z } from "zod";

import { changeDealerStatusAction, updateDealerAction } from "@/app/staff/dealers/actions";
import { ReferenceBlock } from "@/components/reference-block";
import { StaffAccessDenied } from "@/components/staff-access-denied";
import { StaffNotice } from "@/components/staff-notice";
import { requireStaffSession } from "@/lib/staff-auth";
import { getStaffDealer } from "@/lib/staff-dealers";
import { getStaffLicenses } from "@/lib/staff-licensing";

export const dynamic = "force-dynamic";

function targets(status: string) {
  if (status === "internal-review") return ["active", "revoked"];
  if (status === "active") return ["suspended", "revoked"];
  if (status === "suspended") return ["active", "revoked"];
  return [];
}

export default async function DealerDetailPage({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ error?: string; notice?: string }> }) {
  const { id } = await params;
  const parameters = await searchParams;
  if (!z.guid().safeParse(id).success) notFound();
  const { client } = await requireStaffSession();
  const [result, licensesResult] = await Promise.all([getStaffDealer(client, id), getStaffLicenses(client)]);
  if (!result.ok && result.code === "access_denied") return <main className="staff-main"><StaffAccessDenied /></main>;
  if (!result.ok) return <main className="staff-main"><section className="notice-panel"><h1>The dealer record could not be loaded</h1><p>No authoritative data was changed.</p></section></main>;
  if (!result.data) notFound();
  const dealer = result.data;
  const licenses = licensesResult.ok ? licensesResult.data.filter((license) => license.dealer_reference === dealer.public_reference) : [];
  const statusTargets = targets(dealer.status_code);

  return <main className="staff-main">
    <header className="staff-page-header"><div><p className="eyebrow">Business customer</p><h1>{dealer.display_name}</h1><p>{dealer.status_label} · {dealer.dealer_type_label} · {dealer.jurisdiction_label}</p></div><div className="staff-button-row"><Link className="button button-secondary" href="/staff/dealers">Back to customers</Link><Link className="button button-primary" href="/staff/licensing/new">Issue license</Link></div></header>
    <ReferenceBlock label="Dealer reference" reference={dealer.public_reference} status={dealer.status_label}/>
    <StaffNotice error={parameters.error} notice={parameters.notice} />
    <section className="customer-license-section"><div className="inventory-section-heading"><div><p className="eyebrow">Licenses</p><h2>What this business may order</h2></div></div>{licenses.length > 0 ? <div className="customer-license-list">{licenses.map((license) => <Link href={`/staff/licensing/${license.id}`} key={license.id}><span className={`staff-status staff-status-${license.status_code}`}>{license.status_label}</span><strong>{license.license_class_label}</strong><small>{license.endorsements.filter((item) => !item.revoked_at).length} endorsement{license.endorsements.filter((item) => !item.revoked_at).length === 1 ? "" : "s"}</small></Link>)}</div> : <div className="empty-state"><p>No license is linked to this business yet.</p><Link className="button button-primary" href="/staff/licensing/new">Issue license</Link></div>}</section>
    <details className="staff-tools-panel inline-tools-panel customer-record-tools"><summary><span><span><strong>Edit business record</strong><small>Public details, internal notes, and authorization status</small></span></span><span>Open</span></summary><div className="staff-tools-content">
    <section className="detail-grid"><article className="detail-card"><p className="eyebrow">Current authority</p><h2>{dealer.status_label}</h2><dl><div><dt>Effective from</dt><dd>{new Date(dealer.effective_from).toLocaleString()}</dd></div><div><dt>Public record</dt><dd>{dealer.public_disclosure_enabled ? "Published" : "Private"}</dd></div></dl></article></section>
    <form action={updateDealerAction} className="staff-form">
      <input name="dealer_authorization_id" type="hidden" value={dealer.id} /><input name="expected_version" type="hidden" value={dealer.version} />
      <section className="form-section"><div><p className="eyebrow">Versioned details</p><h2>Identity and public presentation</h2></div><div className="form-grid">
        <label className="field"><span>Legal name</span><input defaultValue={dealer.legal_name} maxLength={200} name="legal_name" required /></label>
        <label className="field"><span>Internal display name</span><input defaultValue={dealer.display_name} maxLength={200} name="display_name" required /></label>
        <label className="field"><span>Public display name</span><input defaultValue={dealer.public_display_name ?? ""} maxLength={200} name="public_display_name" /></label>
        <label className="field"><span>Public premises</span><input defaultValue={dealer.approved_premises_public ?? ""} maxLength={1000} name="approved_premises_public" /></label>
        <label className="field field-full"><span>Public notes</span><textarea defaultValue={dealer.public_notes} maxLength={1000} name="public_notes" rows={3} /></label>
        <label className="field field-full"><span>Private notes</span><textarea defaultValue={dealer.private_notes} maxLength={4000} name="private_notes" rows={4} /></label>
        <label className="checkbox-field"><input defaultChecked={dealer.public_disclosure_enabled} name="public_disclosure_enabled" type="checkbox" /><span>Publish this authorization in verification and exports</span></label>
        <label className="field field-full"><span>Audit reason</span><textarea maxLength={500} name="reason" required rows={3} /></label>
      </div></section><button className="button button-primary" type="submit">Save dealer details</button>
    </form>
    {statusTargets.length > 0 && <form action={changeDealerStatusAction} className="staff-form"><input name="dealer_authorization_id" type="hidden" value={dealer.id} /><input name="expected_version" type="hidden" value={dealer.version} /><section className="form-section"><div><p className="eyebrow">Authority decision</p><h2>Change status</h2></div><div className="form-grid"><label className="field"><span>Target status</span><select name="target_status_code" required>{statusTargets.map((status) => <option key={status} value={status}>{status.replaceAll("-", " ")}</option>)}</select></label><label className="field field-full"><span>Decision reason</span><textarea maxLength={500} name="reason" required rows={3} /></label></div></section><button className="button button-primary" type="submit">Record status decision</button></form>}
    </div></details>
  </main>;
}
