import Link from "next/link";
import { notFound } from "next/navigation";

import {
  changeAssetStatusAction,
  inspectAssetAction,
  releaseAssetReservationAction,
  reserveAssetAction,
  transferAssetAction,
} from "@/app/staff/assets/actions";
import { AssetNotice } from "@/components/asset-notice";
import { ReferenceBlock } from "@/components/reference-block";
import { StaffAccessDenied } from "@/components/staff-access-denied";
import { getStaffAssetWorkspace, type AssetWorkspace } from "@/lib/assets";
import { getDefaultLocale } from "@/lib/env";
import { requireStaffSession } from "@/lib/staff-auth";

interface PageProps { params: Promise<{ reference: string }>; searchParams: Promise<{ error?: string; notice?: string }> }

function lifecycleOptions(status: AssetWorkspace["assets"][number]["status"]) {
  if (status === "missing") return ["available"];
  if (status === "seized") return ["available", "retired", "destroyed"];
  if (status === "damaged") return ["available", "missing", "seized", "retired", "destroyed"];
  if (status === "available" || status === "in_custody") return ["missing", "damaged", "seized", "retired", "destroyed"];
  return [];
}

export default async function AssetPage({ params, searchParams }: PageProps) {
  const [{ reference }, parameters] = await Promise.all([params, searchParams]);
  const { client } = await requireStaffSession();
  const result = await getStaffAssetWorkspace(client);
  if (!result.ok && result.code === "access_denied") return <main className="staff-main"><StaffAccessDenied /></main>;
  if (!result.ok) return <main className="staff-main"><section className="notice-panel"><h1>Asset unavailable</h1><p>No fallback custody record was used.</p></section></main>;
  const workspace = result.data;
  const asset = workspace.assets.find((entry) => entry.public_reference === decodeURIComponent(reference).toUpperCase());
  if (!asset) notFound();

  const returnTo = `/staff/assets/${asset.public_reference}`;
  const matchingLines = workspace.order_lines.filter((line) => line.item_id === asset.item_id);
  const canOperate = !asset.active_reservation && !["missing", "seized", "retired", "destroyed"].includes(asset.status);
  const statusOptions = lifecycleOptions(asset.status);
  const locale = getDefaultLocale();

  return <main className="staff-main">
    <header className="staff-page-header"><div><p className="eyebrow">Serialized asset</p><h1>{asset.item_name}</h1><p>Custody, allocation, condition, and lifecycle actions for one individually controlled good.</p></div><div className="staff-button-row"><Link className="button button-secondary" href="/staff/assets">Back to asset queue</Link>{asset.active_reservation && <Link className="button button-primary" href="/staff/assets/fulfillment">Ready handoffs</Link>}</div></header>
    <ReferenceBlock label="Asset reference" reference={asset.public_reference} status={asset.status}/>
    <AssetNotice error={parameters.error} notice={parameters.notice}/>

    <section className="inventory-section"><div className="inventory-section-heading"><div><p className="eyebrow">Current custody</p><h2>Authoritative position</h2></div><p>These fields are maintained from accepted custody events.</p></div><dl className="order-facts object-facts"><div><dt>Item</dt><dd>{asset.item_code} · {asset.item_name}</dd></div><div><dt>Serial or marking</dt><dd>{asset.serial_marking || "Not recorded"}</dd></div><div><dt>Owner</dt><dd>{asset.owner_party_name}</dd></div><div><dt>Custodian</dt><dd>{asset.custodian_party_name}</dd></div><div><dt>Location</dt><dd>{asset.warehouse_name ? `${asset.warehouse_name} / ${asset.location_name}` : "External custody"}</dd></div><div><dt>Condition</dt><dd>{asset.condition_code}</dd></div><div><dt>Registered</dt><dd>{new Date(asset.registered_at).toLocaleString(locale)}</dd></div><div><dt>Inspection due</dt><dd>{asset.next_inspection_due_at ? new Date(asset.next_inspection_due_at).toLocaleDateString(locale) : "Not scheduled"}</dd></div></dl></section>

    <div className="inventory-command-grid material-workspace-grid">
      {asset.active_reservation ? <section className="staff-form inventory-command-card"><div><p className="eyebrow">Exclusive allocation</p><h2>{asset.active_reservation.order_reference}</h2><p>{asset.active_reservation.public_reference} expires {new Date(asset.active_reservation.expires_at).toLocaleString(locale)}.</p></div><form action={releaseAssetReservationAction} className="inventory-command-form"><input name="return_to" type="hidden" value={returnTo}/><input name="asset_reservation_id" type="hidden" value={asset.active_reservation.id}/><input name="expected_version" type="hidden" value={asset.active_reservation.version}/><label className="field"><span>Reason</span><input maxLength={500} name="reason" required/></label><button className="button button-secondary">{new Date(asset.active_reservation.expires_at) <= new Date() ? "Finalize expiry" : "Release allocation"}</button></form></section> : workspace.capabilities.can_reserve && asset.status === "available" ? <section className="staff-form inventory-command-card"><div><p className="eyebrow">Exclusive allocation</p><h2>Allocate to approved demand</h2><p>The allocation is a 48-hour claim and does not complete handoff.</p></div>{matchingLines.length ? <form action={reserveAssetAction} className="inventory-command-form"><input name="return_to" type="hidden" value={returnTo}/><input name="asset_id" type="hidden" value={asset.id}/><input name="expected_version" type="hidden" value={asset.version}/><label className="field"><span>Approved order line</span><select defaultValue="" name="order_line_id" required><option disabled value="">Choose demand</option>{matchingLines.map((line) => <option key={line.id} value={line.id}>{line.order_reference} · line {line.line_number} · {line.ordering_party_name}</option>)}</select></label><label className="field"><span>Reason</span><input maxLength={500} name="reason" required/></label><button className="button button-primary">Allocate for 48 hours</button></form> : <p className="empty-state">No approved unique order line is waiting for this item.</p>}</section> : null}

      {workspace.capabilities.can_transfer && canOperate && <section className="staff-form inventory-command-card"><div><p className="eyebrow">Custody</p><h2>Record accepted handoff</h2><p>Use only after the new custodian has accepted the asset.</p></div><form action={transferAssetAction} className="inventory-command-form"><input name="return_to" type="hidden" value={returnTo}/><input name="asset_id" type="hidden" value={asset.id}/><input name="expected_version" type="hidden" value={asset.version}/><label className="field"><span>Destination</span><select defaultValue="" name="destination" required><option disabled value="">Choose custodian or location</option><optgroup label="Warehouse locations">{workspace.locations.map((location) => <option key={location.id} value={`location:${location.id}:${location.custodian_party_id}`}>{location.warehouse_name} / {location.display_name}</option>)}</optgroup><optgroup label="External custodians">{workspace.parties.map((party) => <option key={party.id} value={`party:${party.id}`}>{party.display_name}</option>)}</optgroup></select></label><label className="field"><span>Condition at acceptance</span><select defaultValue={asset.condition_code} name="condition_code">{["excellent","good","fair","damaged","unknown"].map((value) => <option key={value}>{value}</option>)}</select></label><label className="field"><span>Handoff evidence</span><input maxLength={500} name="reason" required/></label><button className="button button-primary">Record custody transfer</button></form></section>}

      {workspace.capabilities.can_inspect && canOperate && <section className="staff-form inventory-command-card"><div><p className="eyebrow">Condition</p><h2>Record inspection</h2></div><form action={inspectAssetAction} className="inventory-command-form"><input name="return_to" type="hidden" value={returnTo}/><input name="asset_id" type="hidden" value={asset.id}/><input name="expected_version" type="hidden" value={asset.version}/><label className="field"><span>Observed condition</span><select defaultValue={asset.condition_code} name="condition_code">{["excellent","good","fair","damaged","unknown"].map((value) => <option key={value}>{value}</option>)}</select></label><label className="field"><span>Observation</span><textarea maxLength={4000} name="observation" required rows={3}/></label><label className="field"><span>Next due date</span><input name="next_due_date" type="date"/></label><label className="field"><span>Reason</span><input maxLength={500} name="reason" required/></label><button className="button button-secondary">Record inspection</button></form></section>}

      {workspace.capabilities.can_manage_lifecycle && statusOptions.length > 0 && !asset.active_reservation && <section className="staff-form inventory-command-card"><div><p className="eyebrow">Controlled state</p><h2>Record lifecycle event</h2><p>Missing, damaged, seized, retired, and destroyed are explicit evidence-backed states.</p></div><form action={changeAssetStatusAction} className="inventory-command-form"><input name="return_to" type="hidden" value={returnTo}/><input name="asset_id" type="hidden" value={asset.id}/><input name="expected_version" type="hidden" value={asset.version}/><label className="field"><span>New state</span><select defaultValue="" name="status" required><option disabled value="">Choose state</option>{statusOptions.map((value) => <option key={value}>{value}</option>)}</select></label><label className="field"><span>Authority or evidence reason</span><input maxLength={500} name="reason" required/></label><button className="button button-secondary">Record lifecycle event</button></form></section>}
    </div>
  </main>;
}
