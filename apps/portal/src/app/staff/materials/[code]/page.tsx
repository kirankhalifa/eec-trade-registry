import Link from "next/link";
import { notFound } from "next/navigation";

import {
  createOfferAction,
  recordDeliveryAction,
  registerSupplierAction,
  saveSupplyPolicyAction,
} from "@/app/staff/economy/actions";
import { EconomyNotice } from "@/components/economy-notice";
import { ReferenceBlock } from "@/components/reference-block";
import { StaffAccessDenied } from "@/components/staff-access-denied";
import { getStaffEconomyWorkspace } from "@/lib/economy";
import { requireStaffSession } from "@/lib/staff-auth";

interface PageProps {
  params: Promise<{ code: string }>;
  searchParams: Promise<{ error?: string; notice?: string }>;
}

const number = (value: number) => new Intl.NumberFormat(undefined, { maximumFractionDigits: 3 }).format(value);
const money = (value: number, code = "SEP") => `${new Intl.NumberFormat().format(value)} ${code}`;

export default async function MaterialPage({ params, searchParams }: PageProps) {
  const [{ code }, parameters] = await Promise.all([params, searchParams]);
  const { client } = await requireStaffSession();
  const result = await getStaffEconomyWorkspace(client);
  if (!result.ok && result.code === "access_denied") return <main className="staff-main"><StaffAccessDenied /></main>;
  if (!result.ok) return <main className="staff-main"><section className="notice-panel"><h1>Material unavailable</h1><p>The authoritative economic workspace could not be loaded.</p></section></main>;

  const workspace = result.data;
  const position = workspace.positions.find((entry) => entry.item_code.toLowerCase() === decodeURIComponent(code).toLowerCase());
  if (!position) notFound();

  const returnTo = `/staff/materials/${position.item_code}`;
  const offers = workspace.offers.filter((offer) => offer.item_id === position.item_id);
  const currentOffer = offers.find((offer) => offer.is_current);
  const activeSuppliers = workspace.suppliers.filter((supplier) => supplier.status === "active");
  const receivingLocations = workspace.warehouses.flatMap((warehouse) => warehouse.locations
    .filter((location) => location.location_type === "receiving")
    .map((location) => ({ ...location, warehouseName: warehouse.display_name })));
  const currency = workspace.currencies.find((entry) => entry.code === "SEP") ?? workspace.currencies[0];
  const jurisdiction = workspace.jurisdictions[0];

  return <main className="staff-main">
    <header className="staff-page-header"><div><p className="eyebrow">Material record</p><h1>{position.item_name}</h1><p>One place for reserve policy, guaranteed buying rate, delivery intake, and current ledger position.</p></div><div className="staff-button-row"><Link className="button button-secondary" href="/staff/economy">Back to economy queue</Link></div></header>
    <ReferenceBlock label="Material code" reference={position.item_code} status={position.reserve_state.replaceAll("_", " ")} />
    <EconomyNotice error={parameters.error} notice={parameters.notice} />

    <section className="inventory-summary" aria-label={`${position.item_name} position`}>
      <article><span>On hand</span><strong>{number(position.on_hand)}</strong></article>
      <article><span>Reserved</span><strong>{number(position.reserved)}</strong></article>
      <article><span>Available</span><strong>{number(position.available)}</strong></article>
      <article><span>Approved unmet demand</span><strong>{number(position.backordered)}</strong></article>
    </section>

    <section className="policy-principle"><strong>Policy sets the targets.</strong><span>The inventory amounts above come only from posted ledger entries and active reservations.</span></section>

    <div className="inventory-command-grid material-workspace-grid">
      <section className="staff-form inventory-command-card"><div><p className="eyebrow">Reserve policy</p><h2>Set safety levels</h2><p>Target is the desired operating reserve. The other thresholds drive warnings and surplus visibility.</p></div><form action={saveSupplyPolicyAction} className="inventory-command-form">
        <input name="return_to" type="hidden" value={returnTo}/><input name="item_id" type="hidden" value={position.item_id}/><input name="expected_version" type="hidden" value={position.policy_version}/><input name="supply_mode" type="hidden" value={position.supply_mode}/>
        {position.procurement_enabled && <input name="procurement_enabled" type="hidden" value="on"/>}{position.player_sourced_only && <input name="player_sourced_only" type="hidden" value="on"/>}{position.admin_receipt_allowed && <input name="admin_receipt_allowed" type="hidden" value="on"/>}{position.direct_individual_allowed && <input name="direct_individual_allowed" type="hidden" value="on"/>}
        <label className="field"><span>Target reserve</span><input defaultValue={position.target_level ?? ""} min="0" name="target_level" required step="0.001" type="number"/></label>
        <details className="advanced-fields"><summary>Warning and surplus levels</summary><div>{([['critical_level','Critical warning',position.critical_level],['minimum_level','Low-stock warning',position.minimum_level],['surplus_level','Surplus begins',position.surplus_level],['direct_weekly_limit','Personal weekly limit',position.direct_weekly_limit],['business_bulk_review_threshold','Bulk review threshold',position.business_bulk_review_threshold]] as const).map(([name,label,value]) => <label className="field" key={name}><span>{label}</span><input defaultValue={value ?? ""} min="0" name={name} step="0.001" type="number"/></label>)}</div></details>
        <label className="field"><span>Reason</span><input defaultValue="Reserve policy reviewed." maxLength={500} name="reason" required/></label><button className="button button-primary">Save reserve policy</button>
      </form></section>

      <section className="staff-form inventory-command-card"><div><p className="eyebrow">Guaranteed floor</p><h2>{currentOffer ? "Publish a replacement rate" : "Publish purchase rate"}</h2><p>{currentOffer ? `Current guarantee: ${money(currentOffer.amount_minor, currentOffer.currency_code)} per ${currentOffer.unit_code}.` : "No guaranteed buying rate is active."}</p></div>{currency ? <form action={createOfferAction} className="inventory-command-form">
        <input name="return_to" type="hidden" value={returnTo}/><input name="item_id" type="hidden" value={position.item_id}/><input name="currency_id" type="hidden" value={currency.id}/><input name="effective_from" type="hidden" value={new Date().toISOString()}/>
        <p className="derived-choice"><span>Applies to</span><strong>{position.item_name}</strong><small>Paid in {currency.code} · {currency.display_name}</small></p>
        <label className="field"><span>Guaranteed amount per {position.unit_code}</span><input min="1" name="amount_minor" required step="1" type="number"/></label><label className="field"><span>Minimum delivery</span><input defaultValue="1" min="0.001" name="minimum_quantity" required step="0.001" type="number"/></label>
        <details className="advanced-fields"><summary>Review threshold, end date, and notes</summary><div><label className="field"><span>Staff-review quantity</span><input min="0.001" name="staff_review_quantity" step="0.001" type="number"/></label><label className="field"><span>Ends</span><input name="effective_until" type="datetime-local"/></label><label className="field"><span>Policy notes</span><textarea maxLength={2000} name="notes" rows={2}/></label></div></details>
        <label className="field"><span>Reason</span><input defaultValue="Guaranteed purchase rate approved." maxLength={500} name="reason" required/></label><button className="button button-primary">Publish purchase rate</button>
      </form> : <p className="empty-state">The fixed SEP currency is not configured.</p>}</section>

      <section className="staff-form inventory-command-card"><div><p className="eyebrow">Physical intake</p><h2>Receive delivery</h2><p>Accept this material from a registered supplier at the current guaranteed rate.</p></div>{currentOffer && activeSuppliers.length > 0 && receivingLocations.length > 0 ? <form action={recordDeliveryAction} className="inventory-command-form">
        <input name="return_to" type="hidden" value={returnTo}/><input name="offer_id" type="hidden" value={currentOffer.id}/>
        <label className="field"><span>Supplier</span><select defaultValue="" name="supplier_id" required><option disabled value="">Choose supplier</option>{activeSuppliers.map((supplier) => <option key={supplier.id} value={supplier.id}>{supplier.public_reference} · {supplier.display_name}</option>)}</select></label>
        {receivingLocations.length === 1 ? <input name="stock_location_id" type="hidden" value={receivingLocations[0].id}/> : <label className="field"><span>Receive into</span><select defaultValue="" name="stock_location_id" required><option disabled value="">Choose location</option>{receivingLocations.map((location) => <option key={location.id} value={location.id}>{location.warehouseName} · {location.display_name}</option>)}</select></label>}
        <p className="derived-choice"><span>Rate</span><strong>{money(currentOffer.amount_minor, currentOffer.currency_code)} per {currentOffer.unit_code}</strong></p><label className="field"><span>Accepted quantity</span><input autoFocus min="0.001" name="quantity" required step="0.001" type="number"/></label><input name="reason" type="hidden" value="Supplier delivery counted and accepted at receiving."/><button className="button button-primary">Accept delivery</button>
      </form> : <div className="empty-state"><p>{!currentOffer ? "Publish a purchase rate before receiving this material." : !activeSuppliers.length ? "Register the supplier before accepting a delivery." : "Configure a receiving location first."}</p></div>}
        {jurisdiction && <details className="advanced-fields"><summary>Supplier not listed? Register them</summary><form action={registerSupplierAction} className="inventory-command-form"><input name="return_to" type="hidden" value={returnTo}/><input name="jurisdiction_id" type="hidden" value={jurisdiction.id}/><fieldset className="segmented-choice"><legend>Supplier type</legend>{workspace.party_types.slice(0,2).map((type, index) => <label key={type.code}><input defaultChecked={index === 0} name="party_type_code" type="radio" value={type.code}/><span>{type.display_name}</span></label>)}</fieldset><label className="field"><span>Character or organization name</span><input maxLength={300} name="legal_name" placeholder="Example: Aurelion Earandil" required/></label><label className="field"><span>Display name</span><input maxLength={200} name="display_name" placeholder="Usually the same name" required/></label><label className="field"><span>Private notes</span><textarea maxLength={2000} name="notes" rows={2}/></label><input name="reason" type="hidden" value="Supplier registered for material delivery."/><button className="button button-secondary">Register supplier</button></form></details>}
      </section>
    </div>

    <section className="inventory-section"><div className="inventory-section-heading"><div><p className="eyebrow">History</p><h2>Offers and deliveries</h2></div><p>Every accepted delivery posts an immutable inventory receipt.</p></div><div className="inventory-table-wrap"><table className="inventory-table"><thead><tr><th>Record</th><th>Quantity or rate</th><th>Status</th></tr></thead><tbody>{offers.map((offer) => <tr key={offer.id}><td>Purchase offer<small>{offer.effective_from}</small></td><td>{money(offer.amount_minor, offer.currency_code)} per {offer.unit_code}</td><td>{offer.is_current ? "current" : offer.status}</td></tr>)}{workspace.deliveries.filter((delivery) => delivery.item_id === position.item_id).map((delivery) => <tr key={delivery.id}><td>{delivery.public_reference}<small>{delivery.supplier_name}</small></td><td>{number(delivery.quantity)} {delivery.unit_code}</td><td>{delivery.settlement_status}</td></tr>)}</tbody></table></div></section>
  </main>;
}
