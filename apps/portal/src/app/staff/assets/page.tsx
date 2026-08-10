import Link from "next/link";

import { signOutAction } from "@/app/staff/actions";
import {
  changeAssetStatusAction,
  inspectAssetAction,
  registerAssetAction,
  releaseAssetReservationAction,
  reserveAssetAction,
  transferAssetAction,
} from "@/app/staff/assets/actions";
import { AssetNotice } from "@/components/asset-notice";
import { StaffAccessDenied } from "@/components/staff-access-denied";
import { getStaffAssetWorkspace, type AssetWorkspace } from "@/lib/assets";
import { getDefaultLocale } from "@/lib/env";
import { requireStaffSession } from "@/lib/staff-auth";

interface StaffAssetsPageProps { searchParams: Promise<{ error?: string; notice?: string }> }

function lifecycleOptions(status: AssetWorkspace["assets"][number]["status"]) {
  if (status === "missing") return ["available"];
  if (status === "seized") return ["available", "retired", "destroyed"];
  if (status === "damaged") return ["available", "missing", "seized", "retired", "destroyed"];
  if (status === "available" || status === "in_custody") {
    return ["missing", "damaged", "seized", "retired", "destroyed"];
  }
  return [];
}

export default async function StaffAssetsPage({ searchParams }: StaffAssetsPageProps) {
  const parameters = await searchParams;
  const { client } = await requireStaffSession();
  const result = await getStaffAssetWorkspace(client);
  if (!result.ok && result.code === "access_denied") return <main className="staff-main"><StaffAccessDenied /></main>;
  if (!result.ok) return <main className="staff-main"><section className="notice-panel"><h1>Asset registry unavailable</h1><p>No fallback custody state was used and no authoritative record was changed.</p></section></main>;
  const workspace = result.data;
  const locale = getDefaultLocale();
  const active = workspace.assets.filter((asset) => !["retired", "destroyed"].includes(asset.status)).length;
  const allocated = workspace.assets.filter((asset) => asset.active_reservation).length;
  const exceptions = workspace.assets.filter((asset) => ["missing", "damaged", "seized"].includes(asset.status)).length;

  return (
    <main className="staff-main">
      <header className="staff-page-header">
        <div>
          <p className="eyebrow">Authenticated staff - individual custody</p>
          <h1>Serialized asset registry</h1>
          <p>Register unique goods, allocate them exclusively, record accepted custody, inspect condition, and preserve every lifecycle event.</p>
        </div>
        <div className="staff-button-row">
          <Link className="button button-secondary" href="/staff/inventory">Inventory</Link>
          <Link className="button button-secondary" href="/staff/transfers">Transfers</Link>
          <Link className="button button-secondary" href="/staff/consignments">Consignments</Link>
          <Link className="button button-secondary" href="/staff/orders">Orders</Link>
          <form action={signOutAction}><button className="button button-primary" type="submit">Sign out</button></form>
        </div>
      </header>
      <AssetNotice error={parameters.error} notice={parameters.notice} />
      <section className="inventory-summary" aria-label="Serialized asset totals">
        <article><span>Registered</span><strong>{workspace.assets.length}</strong></article>
        <article><span>Active</span><strong>{active}</strong></article>
        <article><span>Allocated</span><strong>{allocated}</strong></article>
        <article><span>Exceptions</span><strong>{exceptions}</strong></article>
      </section>

      {workspace.capabilities.can_register && (
        <section className="inventory-section">
          <div className="inventory-section-heading"><div><p className="eyebrow">Identity creation</p><h2>Register asset</h2></div><p>One database command creates the stable identity and initial custody event.</p></div>
          <form action={registerAssetAction} className="inventory-command-form inventory-receipt-form">
            <label className="field"><span>Serialized item</span><select name="item_id" required><option value="">Choose item</option>{workspace.items.map((item) => <option key={item.id} value={item.id}>{item.item_code} - {item.display_name}</option>)}</select></label>
            <label className="field"><span>Initial location</span><select name="stock_location_id" required><option value="">Choose location</option>{workspace.locations.map((location) => <option key={location.id} value={location.id}>{location.warehouse_name} / {location.display_name}</option>)}</select></label>
            <label className="field"><span>Serial or marking (optional)</span><input maxLength={200} name="serial_marking" /></label>
            <label className="field"><span>Condition</span><select defaultValue="unknown" name="condition_code">{["excellent", "good", "fair", "damaged", "unknown"].map((value) => <option key={value} value={value}>{value}</option>)}</select></label>
            <label className="field"><span>Provenance summary</span><textarea maxLength={4000} name="provenance_summary" rows={3} /></label>
            <label className="field"><span>Registration reason</span><textarea maxLength={500} name="reason" required rows={3} /></label>
            <button className="button button-primary" type="submit">Register serialized asset</button>
          </form>
        </section>
      )}

      <section className="inventory-section">
        <div className="inventory-section-heading"><div><p className="eyebrow">Immutable identity trail</p><h2>Asset register</h2></div><p>Current fields are transactionally consistent projections of accepted events.</p></div>
        <div className="inventory-reservation-list">
          {workspace.assets.map((asset) => {
            const matchingLines = workspace.order_lines.filter((line) => line.item_id === asset.item_id);
            const canOperate = !asset.active_reservation && !["missing", "seized", "retired", "destroyed"].includes(asset.status);
            const statusOptions = lifecycleOptions(asset.status);
            return (
              <article className="inventory-reservation-card" key={asset.id}>
                <header><div><span className={`order-status order-status-${asset.status}`}>{asset.status}</span><h3>{asset.public_reference}</h3></div><strong>{asset.item_code}</strong></header>
                <p>{asset.item_name}{asset.serial_marking ? ` - ${asset.serial_marking}` : ""}</p>
                <dl className="order-facts">
                  <div><dt>Owner</dt><dd>{asset.owner_party_name}</dd></div>
                  <div><dt>Custodian</dt><dd>{asset.custodian_party_name}</dd></div>
                  <div><dt>Location</dt><dd>{asset.warehouse_name ? `${asset.warehouse_name} / ${asset.location_name}` : "External custody"}</dd></div>
                  <div><dt>Condition</dt><dd>{asset.condition_code}</dd></div>
                  <div><dt>Registered</dt><dd>{new Date(asset.registered_at).toLocaleString(locale)}</dd></div>
                  <div><dt>Inspection due</dt><dd>{asset.next_inspection_due_at ? new Date(asset.next_inspection_due_at).toLocaleDateString(locale) : "Not scheduled"}</dd></div>
                </dl>

                {asset.active_reservation ? (
                  <form action={releaseAssetReservationAction} className="inventory-command-form">
                    <p><strong>{asset.active_reservation.public_reference}</strong> for {asset.active_reservation.order_reference}, expires {new Date(asset.active_reservation.expires_at).toLocaleString(locale)}</p>
                    <input name="asset_reservation_id" type="hidden" value={asset.active_reservation.id} />
                    <input name="expected_version" type="hidden" value={asset.active_reservation.version} />
                    <label className="field"><span>{new Date(asset.active_reservation.expires_at) <= new Date() ? "Expiry reason" : "Release reason"}</span><input maxLength={500} name="reason" required /></label>
                    <button className="button button-secondary" type="submit">{new Date(asset.active_reservation.expires_at) <= new Date() ? "Finalize expiry" : "Release allocation"}</button>
                  </form>
                ) : workspace.capabilities.can_reserve && asset.status === "available" && matchingLines.length > 0 ? (
                  <form action={reserveAssetAction} className="inventory-command-form">
                    <input name="asset_id" type="hidden" value={asset.id} /><input name="expected_version" type="hidden" value={asset.version} />
                    <label className="field"><span>Approved unique order line</span><select name="order_line_id" required><option value="">Choose demand</option>{matchingLines.map((line) => <option key={line.id} value={line.id}>{line.order_reference} / line {line.line_number} / {line.ordering_party_name}</option>)}</select></label>
                    <label className="field"><span>Allocation reason</span><input maxLength={500} name="reason" required /></label>
                    <button className="button button-secondary" type="submit">Allocate for 48 hours</button>
                  </form>
                ) : null}

                {workspace.capabilities.can_transfer && canOperate && (
                  <form action={transferAssetAction} className="inventory-command-form">
                    <input name="asset_id" type="hidden" value={asset.id} /><input name="expected_version" type="hidden" value={asset.version} />
                    <label className="field"><span>Accepted destination</span><select name="destination" required><option value="">Choose custodian or location</option><optgroup label="Warehouse locations">{workspace.locations.map((location) => <option key={location.id} value={`location:${location.id}:${location.custodian_party_id}`}>{location.warehouse_name} / {location.display_name}</option>)}</optgroup><optgroup label="External custodians">{workspace.parties.map((party) => <option key={party.id} value={`party:${party.id}`}>{party.display_name}</option>)}</optgroup></select></label>
                    <label className="field"><span>Condition at acceptance</span><select defaultValue={asset.condition_code} name="condition_code">{["excellent", "good", "fair", "damaged", "unknown"].map((value) => <option key={value} value={value}>{value}</option>)}</select></label>
                    <label className="field"><span>Handoff evidence</span><input maxLength={500} name="reason" required /></label>
                    <button className="button button-secondary" type="submit">Record custody transfer</button>
                  </form>
                )}

                {workspace.capabilities.can_inspect && canOperate && (
                  <form action={inspectAssetAction} className="inventory-command-form">
                    <input name="asset_id" type="hidden" value={asset.id} /><input name="expected_version" type="hidden" value={asset.version} />
                    <label className="field"><span>Observed condition</span><select defaultValue={asset.condition_code} name="condition_code">{["excellent", "good", "fair", "damaged", "unknown"].map((value) => <option key={value} value={value}>{value}</option>)}</select></label>
                    <label className="field"><span>Observation</span><textarea maxLength={4000} name="observation" required rows={2} /></label>
                    <label className="field"><span>Next due date (optional)</span><input name="next_due_date" type="date" /></label>
                    <label className="field"><span>Inspection reason</span><input maxLength={500} name="reason" required /></label>
                    <button className="button button-secondary" type="submit">Record inspection</button>
                  </form>
                )}

                {workspace.capabilities.can_manage_lifecycle && statusOptions.length > 0 && !asset.active_reservation && (
                  <form action={changeAssetStatusAction} className="inventory-command-form">
                    <input name="asset_id" type="hidden" value={asset.id} /><input name="expected_version" type="hidden" value={asset.version} />
                    <label className="field"><span>Controlled lifecycle state</span><select name="status" required><option value="">Choose state</option>{statusOptions.map((value) => <option key={value} value={value}>{value}</option>)}</select></label>
                    <label className="field"><span>Authority / evidence reason</span><input maxLength={500} name="reason" required /></label>
                    <button className="button button-secondary" type="submit">Record lifecycle event</button>
                  </form>
                )}
              </article>
            );
          })}
        </div>
        {workspace.assets.length === 0 && <p className="empty-state">No serialized asset has been registered yet.</p>}
      </section>
    </main>
  );
}
