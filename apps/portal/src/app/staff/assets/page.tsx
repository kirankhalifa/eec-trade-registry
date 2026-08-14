import Link from "next/link";

import { registerAssetAction } from "@/app/staff/assets/actions";
import { AssetNotice } from "@/components/asset-notice";
import { StaffAccessDenied } from "@/components/staff-access-denied";
import { getStaffAssetWorkspace } from "@/lib/assets";
import { getDefaultLocale } from "@/lib/env";
import { requireStaffSession } from "@/lib/staff-auth";

interface StaffAssetsPageProps { searchParams: Promise<{ error?: string; notice?: string }> }

export default async function StaffAssetsPage({ searchParams }: StaffAssetsPageProps) {
  const parameters = await searchParams;
  const { client } = await requireStaffSession();
  const result = await getStaffAssetWorkspace(client);
  if (!result.ok && result.code === "access_denied") return <main className="staff-main"><StaffAccessDenied /></main>;
  if (!result.ok) return <main className="staff-main"><section className="notice-panel"><h1>Asset registry unavailable</h1><p>No fallback custody state was used.</p></section></main>;
  const workspace = result.data;
  const locale = getDefaultLocale();
  const active = workspace.assets.filter((asset) => !["retired", "destroyed"].includes(asset.status)).length;
  const allocated = workspace.assets.filter((asset) => asset.active_reservation).length;
  const exceptions = workspace.assets.filter((asset) => ["missing", "damaged", "seized"].includes(asset.status)).length;

  return <main className="staff-main">
    <header className="staff-page-header"><div><p className="eyebrow">Individual custody queue</p><h1>Serialized assets</h1><p>Find the asset needing attention, then open its record for allocation, custody, inspection, and lifecycle actions.</p></div><div className="staff-button-row"><Link className="button button-primary" href="/staff/assets/fulfillment">Ready handoffs</Link><Link className="button button-secondary" href="/staff/compliance">Compliance</Link></div></header>
    <AssetNotice error={parameters.error} notice={parameters.notice}/>
    <section className="inventory-summary" aria-label="Serialized asset totals"><article><span>Registered</span><strong>{workspace.assets.length}</strong></article><article><span>Active</span><strong>{active}</strong></article><article><span>Allocated</span><strong>{allocated}</strong></article><article><span>Exceptions</span><strong>{exceptions}</strong></article></section>

    <section className="inventory-section"><div className="inventory-section-heading"><div><p className="eyebrow">Action queue</p><h2>Asset register</h2></div><p>Queues show what exists. The asset record is where work happens.</p></div><div className="inventory-table-wrap"><table className="inventory-table"><thead><tr><th>Reference</th><th>Item</th><th>Status</th><th>Custody</th><th>Inspection</th><th>Next action</th></tr></thead><tbody>{workspace.assets.map((asset) => <tr key={asset.id}><td><Link href={`/staff/assets/${asset.public_reference}`}><strong>{asset.public_reference}</strong></Link><small>{asset.serial_marking || "No marking"}</small></td><td>{asset.item_name}<small>{asset.item_code}</small></td><td><span className={`order-status order-status-${asset.status}`}>{asset.status}</span>{asset.active_reservation && <small>Allocated to {asset.active_reservation.order_reference}</small>}</td><td>{asset.custodian_party_name}<small>{asset.warehouse_name ? `${asset.warehouse_name} / ${asset.location_name}` : "External"}</small></td><td>{asset.next_inspection_due_at ? new Date(asset.next_inspection_due_at).toLocaleDateString(locale) : "Not scheduled"}</td><td><Link className="text-link" href={`/staff/assets/${asset.public_reference}`}>Open asset →</Link></td></tr>)}</tbody></table></div>{!workspace.assets.length && <p className="empty-state">No serialized asset has been registered. Use the registration panel below for the first one.</p>}</section>

    {workspace.capabilities.can_register && <details className="staff-form advanced-fields"><summary>Register a new serialized asset</summary><form action={registerAssetAction} className="inventory-command-form"><label className="field"><span>Serialized item</span><select defaultValue="" name="item_id" required><option disabled value="">Choose item</option>{workspace.items.map((item) => <option key={item.id} value={item.id}>{item.item_code} · {item.display_name}</option>)}</select></label>{workspace.locations.length === 1 ? <input name="stock_location_id" type="hidden" value={workspace.locations[0].id}/> : <label className="field"><span>Initial location</span><select defaultValue="" name="stock_location_id" required><option disabled value="">Choose location</option>{workspace.locations.map((location) => <option key={location.id} value={location.id}>{location.warehouse_name} / {location.display_name}</option>)}</select></label>}<label className="field"><span>Serial or marking</span><input maxLength={200} name="serial_marking"/></label><label className="field"><span>Condition</span><select defaultValue="unknown" name="condition_code">{["excellent","good","fair","damaged","unknown"].map((value) => <option key={value}>{value}</option>)}</select></label><label className="field"><span>Provenance summary</span><textarea maxLength={4000} name="provenance_summary" rows={3}/></label><label className="field"><span>Registration reason</span><textarea maxLength={500} name="reason" required rows={2}/></label><button className="button button-primary">Register asset</button></form></details>}
  </main>;
}
