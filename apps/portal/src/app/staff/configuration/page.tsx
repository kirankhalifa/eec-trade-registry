import Link from "next/link";

import { signOutAction } from "@/app/staff/actions";
import {
  createConfigurationReferenceAction,
  createControlProfileAction,
  quickCreateItemAction,
  quickReceiptAction,
  setItemPublicTermsAction,
} from "@/app/staff/configuration/actions";
import { ConfigurationNotice } from "@/components/configuration-notice";
import { StaffAccessDenied } from "@/components/staff-access-denied";
import { getStaffConfigurationWorkspace } from "@/lib/configuration";
import { getDefaultLocale } from "@/lib/env";
import { requireStaffSession } from "@/lib/staff-auth";

interface PageProps {
  searchParams: Promise<{ error?: string; notice?: string }>;
}

function preferredCode(codes: string[], preferred: string[]) {
  return preferred.find((code) => codes.includes(code)) ?? codes[0] ?? "";
}

export default async function ConfigurationPage({ searchParams }: PageProps) {
  const parameters = await searchParams;
  const { client } = await requireStaffSession();
  const result = await getStaffConfigurationWorkspace(client);
  if (!result.ok && result.code === "access_denied") {
    return <main className="staff-main"><StaffAccessDenied /></main>;
  }
  if (!result.ok) {
    return <main className="staff-main"><section className="notice-panel"><h1>Configuration studio unavailable</h1><p>No fallback data was used and no records were changed.</p></section></main>;
  }

  const workspace = result.data;
  const capabilities = workspace.capabilities;
  const activeCategories = workspace.categories.filter((entry) => entry.active);
  const activeUnits = workspace.units.filter((entry) => entry.active);
  const activeControls = workspace.control_profiles.filter((entry) => entry.active);
  const activeAvailability = workspace.availability_profiles.filter((entry) => entry.active);
  const receiptItems = workspace.items.filter((item) =>
    item.status === "active" && item.inventory_mode === "fungible" && item.admin_receipt_allowed
  );
  const locations = workspace.warehouses.flatMap((warehouse) =>
    warehouse.locations.map((location) => ({ ...location, warehouse_name: warehouse.display_name }))
  );
  const defaultControl = preferredCode(
    activeControls.map((entry) => entry.code),
    ["ordinary-economic", "ordinary"],
  );
  const defaultAvailability = preferredCode(
    activeAvailability.map((entry) => entry.code),
    ["available", "reserve-dependent", "by-request"],
  );
  const publicSchedules = workspace.price_schedules.filter((schedule) => schedule.audience_code === "public");
  const locale = getDefaultLocale();
  const canQuickCreate = capabilities.can_manage_catalogue && capabilities.can_manage_supply_policy;

  return (
    <main className="staff-main">
      <header className="staff-page-header">
        <div>
          <p className="eyebrow">Authenticated staff · rapid administration</p>
          <h1>Configuration and quick operations</h1>
          <p>Create a complete item or post ordinary stock in one short workflow. Supabase still records every authoritative step and the inventory ledger remains immutable.</p>
        </div>
        <div className="staff-button-row">
          <Link className="button button-secondary" href="/staff/inventory">Inventory</Link>
          <Link className="button button-secondary" href="/staff/economy">Economy</Link>
          <Link className="button button-secondary" href="/staff/licensing">Licensing</Link>
          <Link className="button button-secondary" href="/staff">Catalogue</Link>
          <form action={signOutAction}><button className="button button-primary" type="submit">Sign out</button></form>
        </div>
      </header>

      <ConfigurationNotice error={parameters.error} notice={parameters.notice} />

      <section className="configuration-speed-banner">
        <div><span>Target</span><strong>Under 30 seconds</strong></div>
        <p>Name it, classify it, choose how it is supplied, then save. Codes, slugs, audit wording, and receipt references can be generated automatically.</p>
      </section>

      <div className="configuration-quick-grid">
        <section className="staff-form configuration-primary-card">
          <div>
            <p className="eyebrow">One atomic onboarding command</p>
            <h2>Quick-add an item or material</h2>
            <p>The item and its supply policy are always created together. Publication, a price, and permitted opening stock are optional parts of the same transaction.</p>
          </div>
          {!canQuickCreate && <p className="form-error">This requires both catalogue-management and supply-policy authority.</p>}
          <form action={quickCreateItemAction} className="configuration-quick-form">
            <label className="field configuration-name-field"><span>Item name</span><input autoComplete="off" maxLength={200} name="display_name" placeholder="Iron fittings" required /></label>
            <label className="field"><span>Category</span><select name="category_code" required>{activeCategories.map((entry) => <option key={entry.id} value={entry.code}>{entry.display_name}</option>)}</select></label>
            <label className="field"><span>Unit</span><select name="unit_code" required>{activeUnits.map((entry) => <option key={entry.id} value={entry.code}>{entry.display_name}{entry.symbol ? ` (${entry.symbol})` : ""}</option>)}</select></label>
            <label className="field"><span>Supply workflow</span><select defaultValue="warehouse_stocked" name="supply_mode"><option value="warehouse_stocked">Warehouse stocked</option><option value="player_sourced_reserve">Player-sourced reserve</option><option value="made_to_order">Made to order</option><option value="limited_release">Limited release</option><option value="serialized_unique">Serialized unique item</option></select></label>
            <label className="staff-checkbox-field"><input defaultChecked={capabilities.can_manage_publication} disabled={!capabilities.can_manage_publication} name="publish" type="checkbox" /><span>Publish to the public catalogue now</span></label>

            <details className="configuration-advanced">
              <summary>Optional price, opening stock, thresholds, and public wording</summary>
              <div className="staff-form-grid">
                <label className="field staff-field-wide"><span>Description</span><textarea maxLength={4000} name="description" placeholder="Defaults to the item name." rows={2} /></label>
                <label className="field"><span>Item code (optional)</span><input maxLength={32} name="item_code" placeholder="Generated as ITM-####" /></label>
                <label className="field"><span>Public URL slug (optional)</span><input maxLength={80} name="slug" placeholder="Generated from the name" /></label>
                <label className="field"><span>Control profile</span><select defaultValue={defaultControl} name="control_profile_code" required>{activeControls.map((entry) => <option key={entry.id} value={entry.code}>{entry.display_name}</option>)}</select></label>
                <label className="field"><span>Availability wording</span><select defaultValue={defaultAvailability} name="availability_profile_code" required>{activeAvailability.map((entry) => <option key={entry.id} value={entry.code}>{entry.display_name}</option>)}</select></label>
                <label className="field staff-field-wide"><span>Public purchase requirements</span><input maxLength={1000} name="requirement_summary" placeholder="Defaults to contact an authorized representative." /></label>
                <label className="field"><span>Public price schedule</span><select defaultValue={publicSchedules[0]?.id ?? ""} name="price_schedule_id"><option value="">No price yet</option>{publicSchedules.map((entry) => <option key={entry.id} value={entry.id}>{entry.display_name} · {entry.currency_code}</option>)}</select></label>
                <label className="field"><span>Price (optional)</span><input disabled={!capabilities.can_manage_pricing} min="0" name="price_amount_minor" step="1" type="number" /></label>
                <label className="field"><span>Opening location</span><select defaultValue={locations[0]?.id ?? ""} name="opening_stock_location_id"><option value="">No opening stock</option>{locations.map((entry) => <option key={entry.id} value={entry.id}>{entry.warehouse_name} · {entry.display_name}</option>)}</select></label>
                <label className="field"><span>Opening quantity</span><input disabled={!capabilities.can_post_receipts} min="0.001" name="opening_quantity" step="0.001" type="number" /></label>
                <label className="field"><span>Receipt source (optional)</span><input maxLength={200} name="source_reference" placeholder="Generated if omitted" /></label>
                <label className="field"><span>Critical level</span><input min="0" name="critical_level" step="0.001" type="number" /></label>
                <label className="field"><span>Minimum level</span><input min="0" name="minimum_level" step="0.001" type="number" /></label>
                <label className="field"><span>Target level</span><input min="0" name="target_level" step="0.001" type="number" /></label>
                <label className="field"><span>Surplus level</span><input min="0" name="surplus_level" step="0.001" type="number" /></label>
                <label className="staff-checkbox-field"><input name="direct_individual_allowed" type="checkbox" /><span>Permit direct individual orders</span></label>
                <label className="field"><span>Personal weekly limit</span><input min="0.001" name="direct_weekly_limit" step="0.001" type="number" /></label>
                <label className="field"><span>Business bulk-review quantity</span><input min="0.001" name="business_bulk_review_threshold" step="0.001" type="number" /></label>
                <label className="field staff-field-wide"><span>Audit note (optional)</span><input maxLength={500} name="reason" placeholder="A useful default is generated if omitted." /></label>
              </div>
            </details>
            <button className="button button-primary configuration-submit" disabled={!canQuickCreate || !activeCategories.length || !activeUnits.length || !activeControls.length || !activeAvailability.length} type="submit">Create complete item</button>
          </form>
        </section>

        <section className="staff-form configuration-receipt-card">
          <div><p className="eyebrow">Three-field stock entry</p><h2>Add ordinary inventory</h2><p>Search by code or name, enter quantity, and post. A source reference and audit note are generated when left blank.</p></div>
          <form action={quickReceiptAction} className="inventory-command-form">
            <label className="field"><span>Item code or name</span><input autoComplete="off" list="quick-receipt-items" name="item_code" placeholder="Start typing…" required /></label>
            <datalist id="quick-receipt-items">{receiptItems.map((item) => <option key={item.id} value={item.item_code}>{item.display_name}</option>)}</datalist>
            <label className="field"><span>Quantity</span><input min="0.001" name="quantity" required step="0.001" type="number" /></label>
            <label className="field"><span>Location</span><select name="stock_location_id" required>{locations.map((entry) => <option key={entry.id} value={entry.id}>{entry.warehouse_name} · {entry.display_name}</option>)}</select></label>
            <details className="configuration-advanced"><summary>Optional receipt details</summary><label className="field"><span>Source reference</span><input maxLength={200} name="source_reference" /></label><label className="field"><span>Audit note</span><input maxLength={500} name="reason" /></label></details>
            <button className="button button-primary" disabled={!capabilities.can_post_receipts || !receiptItems.length || !locations.length} type="submit">Add to inventory</button>
          </form>
          <p className="field-help">Player-sourced reserves do not appear here. Receive those against a supplier and current purchase offer on the <Link href="/staff/economy">Economy desk</Link>.</p>
        </section>
      </div>

      {capabilities.can_manage_configuration && (
        <section className="inventory-section">
          <div className="inventory-section-heading"><div><p className="eyebrow">No-code vocabulary</p><h2>Add categories, units, license types, and endorsements</h2></div><p>New options become available to staff forms immediately.</p></div>
          <div className="configuration-reference-grid">
            <form action={createConfigurationReferenceAction} className="staff-form inventory-command-form">
              <label className="field"><span>Configuration type</span><select name="kind"><option value="item_category">Item category</option><option value="unit">Unit of measure</option><option value="license_class">License type</option><option value="endorsement">License endorsement</option><option value="availability_profile">Availability wording</option></select></label>
              <label className="field"><span>Stable code</span><input maxLength={50} name="code" pattern="[a-z0-9][a-z0-9_-]*" placeholder="smithing-materials" required /></label>
              <label className="field"><span>Staff display name</span><input maxLength={200} name="display_name" required /></label>
              <label className="field"><span>Public display name (optional)</span><input maxLength={200} name="public_display_name" /></label>
              <label className="field"><span>Description</span><textarea maxLength={2000} name="description" rows={2} /></label>
              <label className="field"><span>Unit symbol (units only)</span><input maxLength={30} name="symbol" /></label>
              <label className="field"><span>Decimal places (units only)</span><input defaultValue="0" max="6" min="0" name="quantity_scale" type="number" /></label>
              <label className="field"><span>Display order</span><input defaultValue="0" name="sort_order" type="number" /></label>
              <label className="field"><span>Audit note (optional)</span><input maxLength={500} name="reason" /></label>
              <button className="button button-secondary" type="submit">Add configuration option</button>
            </form>

            <form action={createControlProfileAction} className="staff-form inventory-command-form">
              <div><p className="eyebrow">Behavior, not item names</p><h3>Create a control profile</h3></div>
              <label className="field"><span>Stable code</span><input maxLength={50} name="code" pattern="[a-z0-9][a-z0-9_-]*" required /></label>
              <label className="field"><span>Display name</span><input maxLength={200} name="display_name" required /></label>
              <label className="field"><span>Public explanation</span><textarea maxLength={2000} name="public_description" required rows={3} /></label>
              <label className="staff-checkbox-field"><input name="requires_staff_review" type="checkbox" /><span>Require staff review</span></label>
              <label className="staff-checkbox-field"><input name="requires_transaction_approval" type="checkbox" /><span>Require transaction approval</span></label>
              <label className="staff-checkbox-field"><input name="requires_serial_tracking" type="checkbox" /><span>Require serialized tracking</span></label>
              <label className="field"><span>Audit note (optional)</span><input maxLength={500} name="reason" /></label>
              <button className="button button-secondary" type="submit">Add control profile</button>
            </form>
          </div>
          <div className="configuration-chip-groups">
            <article><h3>Categories</h3><p>{workspace.categories.map((entry) => <span className="configuration-chip" key={entry.id}>{entry.display_name}</span>)}</p></article>
            <article><h3>Units</h3><p>{workspace.units.map((entry) => <span className="configuration-chip" key={entry.id}>{entry.display_name}</span>)}</p></article>
            <article><h3>License types</h3><p>{workspace.license_classes.map((entry) => <span className="configuration-chip" key={entry.id}>{entry.display_name}</span>)}</p></article>
            <article><h3>Endorsements</h3><p>{workspace.endorsements.map((entry) => <span className="configuration-chip" key={entry.id}>{entry.display_name}</span>)}</p></article>
          </div>
        </section>
      )}

      <section className="inventory-section">
        <div className="inventory-section-heading"><div><p className="eyebrow">Effective-dated public presentation</p><h2>Edit publication and price</h2></div><p>Saving creates a new effective version; it does not erase previous public terms.</p></div>
        <div className="configuration-item-list">
          {workspace.items.filter((item) => item.status === "active").map((item) => (
            <details className="configuration-item-card" key={item.id}>
              <summary><span><strong>{item.display_name}</strong><small>{item.item_code} · {item.category_code} · {item.supply_mode?.replaceAll("_", " ") ?? "supply policy missing"}</small></span><span>{item.publication_status === "published" ? "Published" : "Not public"}{item.price_amount_minor !== null ? ` · ${item.price_amount_minor} ${item.currency_code ?? ""}` : " · price unset"}</span></summary>
              <form action={setItemPublicTermsAction} className="staff-form-grid configuration-terms-form">
                <input name="item_id" type="hidden" value={item.id} />
                <label className="staff-checkbox-field staff-field-wide"><input defaultChecked={item.publication_status === "published"} disabled={!capabilities.can_manage_publication} name="publish" type="checkbox" /><span>Published publicly</span></label>
                <label className="field"><span>Public name</span><input defaultValue={item.public_name ?? item.display_name} maxLength={200} name="public_name" required /></label>
                <label className="field"><span>Control</span><select defaultValue={item.control_profile_code ?? defaultControl} name="control_profile_code">{activeControls.map((entry) => <option key={entry.id} value={entry.code}>{entry.display_name}</option>)}</select></label>
                <label className="field"><span>Availability</span><select defaultValue={item.availability_profile_code ?? defaultAvailability} name="availability_profile_code">{activeAvailability.map((entry) => <option key={entry.id} value={entry.code}>{entry.display_name}</option>)}</select></label>
                <label className="field staff-field-wide"><span>Public description</span><textarea defaultValue={item.public_description ?? item.description} maxLength={4000} name="public_description" required rows={2} /></label>
                <label className="field staff-field-wide"><span>Purchase requirements</span><input defaultValue={item.requirement_summary ?? "Contact an authorized representative for current terms and availability."} maxLength={1000} name="requirement_summary" required /></label>
                <label className="field"><span>Bulk minimum</span><input defaultValue={item.bulk_minimum ?? ""} min="0.001" name="bulk_minimum" step="0.001" type="number" /></label>
                <label className="field"><span>Order increment</span><input defaultValue={item.order_increment ?? 1} min="0.001" name="order_increment" required step="0.001" type="number" /></label>
                <label className="field"><span>Price action</span><select defaultValue="keep" disabled={!capabilities.can_manage_pricing} name="price_action"><option value="keep">Keep current price</option><option value="set">Set or replace price</option><option value="clear">Clear price</option></select></label>
                <label className="field"><span>Price schedule</span><select defaultValue={item.price_schedule_id ?? publicSchedules[0]?.id ?? ""} name="price_schedule_id"><option value="">Select schedule</option>{workspace.price_schedules.map((entry) => <option key={entry.id} value={entry.id}>{entry.display_name} · {entry.currency_code}</option>)}</select></label>
                <label className="field"><span>New price</span><input defaultValue={item.price_amount_minor ?? ""} min="0" name="price_amount_minor" step="1" type="number" /></label>
                <label className="field staff-field-wide"><span>Audit note (optional)</span><input maxLength={500} name="reason" /></label>
                <button className="button button-secondary" disabled={!capabilities.can_manage_publication} type="submit">Save public terms</button>
              </form>
            </details>
          ))}
        </div>
      </section>

      <p className="result-count">Configuration snapshot generated {new Date(workspace.generated_at).toLocaleString(locale)}. Balances remain ledger-derived.</p>
    </main>
  );
}
