"use client";

import { useActionState, useMemo, useState } from "react";

import { guidedTradeOrderAction } from "@/app/staff/launch/actions";
import type { LaunchWorkspace } from "@/lib/launch-workspace";
import type { GuidedOrderState, TradeOrderPreview } from "@/lib/order-preview";
import { REGISTRY_CONFIG } from "@/lib/registry-config";

const initialState: GuidedOrderState = {};

function amount(value: number | null, currency: string | null) {
  return value === null ? "To be confirmed" : `${new Intl.NumberFormat().format(value)} ${currency ?? REGISTRY_CONFIG.currency.code}`;
}

function OrderPreview({ preview }: { preview: TradeOrderPreview }) {
  return (
    <aside className="simple-task-summary order-intake-preview" aria-live="polite">
      <div className="simple-summary-status"><span className={preview.valid ? "preview-ready" : "preview-blocked"}>{preview.valid ? "Ready to record" : "Needs attention"}</span></div>
      <p className="eyebrow">Order summary</p>
      <h2>{preview.channel === "direct_individual" ? "Individual purchase" : "Licensed business order"}</h2>
      <div className="simple-preview-lines">{preview.lines.map((line) => <div key={line.item_id}><span><strong>{line.item_name}</strong><small>{line.quantity} {line.unit ?? "units"}</small></span><strong>{amount(line.unit_price_minor === null ? null : line.unit_price_minor * line.quantity, line.currency_code)}</strong>{line.weekly_limit !== null && <small>{line.weekly_remaining} of {line.weekly_limit} available this week before this order</small>}</div>)}</div>
      <div className="simple-task-total"><span>Total</span><strong>{amount(preview.total_amount_minor, preview.currency_code)}</strong></div>
      {preview.warnings.map((warning) => <p className="staff-flash staff-flash-error" key={warning}>{warning}</p>)}
      <details className="advanced-fields"><summary>How the price was chosen</summary><div>{preview.lines.map((line) => <p className="simple-price-source" key={line.item_id}><strong>{line.item_name}</strong><span>{line.price_source}{line.multiplier_basis_points !== null && line.multiplier_basis_points !== 10000 ? ` · ${line.multiplier_basis_points / 10000}×` : ""}</span></p>)}</div></details>
      <p className="simple-summary-note">The order records demand now. Stock only moves when goods are actually handed over.</p>
    </aside>
  );
}

export function GuidedOrderForm({ workspace }: { workspace: LaunchWorkspace }) {
  const jurisdiction = workspace.jurisdictions.find((item) => item.code === REGISTRY_CONFIG.jurisdiction.code) ?? workspace.jurisdictions[0];
  const businessOptions = workspace.businesses.flatMap((business) => business.licenses.map((license) => ({
    businessKey: `${business.party_id}|${business.dealer_authorization_id}|${license.id}|${business.jurisdiction_id}`,
    channel: "staff_assisted_business" as const,
    directId: "",
    key: `business:${license.id}`,
    label: business.party_name,
    secondary: `${license.class} license`,
  })));
  const directOptions = workspace.direct_customers.map((customer) => ({
    businessKey: "",
    channel: "direct_individual" as const,
    directId: customer.party_id,
    key: `direct:${customer.party_id}`,
    label: customer.name,
    secondary: "Individual customer",
  }));
  const buyerOptions = [...businessOptions, ...directOptions];
  const [buyerKey, setBuyerKey] = useState(buyerOptions[0]?.key ?? "new");
  const [lineNumbers, setLineNumbers] = useState([1]);
  const [fulfillment, setFulfillment] = useState<"collection" | "delivery" | "consignment">("collection");
  const [state, action, pending] = useActionState(guidedTradeOrderAction, initialState);
  const selectedBuyer = buyerOptions.find((buyer) => buyer.key === buyerKey);
  const isNewCustomer = buyerKey === "new";
  const isDirect = isNewCustomer || selectedBuyer?.channel === "direct_individual";
  const visibleItems = useMemo(() => isDirect ? workspace.items.filter((item) => item.direct_allowed) : workspace.items, [isDirect, workspace.items]);
  const nextLine = [1, 2, 3, 4, 5].find((number) => !lineNumbers.includes(number)) ?? 5;

  return (
    <form action={action} className="simple-task-layout order-simple-layout">
      <input name="channel" type="hidden" value={isDirect ? "direct_individual" : "staff_assisted_business"} />
      <input name="business_key" type="hidden" value={selectedBuyer?.businessKey ?? ""} />
      <input name="direct_customer_id" type="hidden" value={selectedBuyer?.directId ?? ""} />
      <input name="jurisdiction_id" type="hidden" value={jurisdiction?.id ?? ""} />
      <input name="fulfillment_mode" type="hidden" value={fulfillment} />
      <input name="reason" type="hidden" value="Staff recorded the customer’s order." />

      <section className="simple-task-card simple-order-form">
        <label className="field simple-primary-field">
          <span>Who is buying?</span>
          <select onChange={(event) => setBuyerKey(event.target.value)} value={buyerKey}>
            {businessOptions.length > 0 && <optgroup label="Licensed businesses">{businessOptions.map((buyer) => <option key={buyer.key} value={buyer.key}>{buyer.label} · {buyer.secondary}</option>)}</optgroup>}
            {directOptions.length > 0 && <optgroup label="Individual customers">{directOptions.map((buyer) => <option key={buyer.key} value={buyer.key}>{buyer.label}</option>)}</optgroup>}
            <option value="new">+ New individual customer</option>
          </select>
          {selectedBuyer && <small>{selectedBuyer.channel === "staff_assisted_business" ? "Licensed pricing is selected automatically." : "Individual premium and weekly limit are automatic."}</small>}
        </label>

        {isNewCustomer && <div className="inline-simple-fields"><label className="field"><span>Customer name</span><input autoFocus maxLength={200} name="new_customer_name" required /></label><label className="field"><span>Discord name (optional)</span><input maxLength={300} name="contact_label" /></label></div>}
        {!isNewCustomer && !isDirect && <label className="field"><span>Who is it for? <small>Optional</small></span><input maxLength={300} name="contact_label" placeholder="Leave blank if the business is the recipient" /></label>}
        {!isNewCustomer && isDirect && <input name="contact_label" type="hidden" value="" />}
        {!isNewCustomer && <input name="new_customer_name" type="hidden" value="" />}

        <div className="simple-form-divider" />
        <div className="simple-field-heading"><span>What do they want?</span><small>Add only the goods in this order.</small></div>
        <div className="guided-order-lines">{lineNumbers.map((number, index) => <div className="guided-order-line simple-order-line" key={number}>
          <label className="field"><span>{index === 0 ? "Item" : `Item ${index + 1}`}</span><select defaultValue="" name={`item_id_${number}`} required><option disabled value="">Choose goods</option>{visibleItems.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select></label>
          <label className="field quantity-field"><span>Quantity</span><input defaultValue="1" min="0.001" name={`quantity_${number}`} required step="0.001" type="number" /></label>
          {lineNumbers.length > 1 && <button aria-label={`Remove item ${index + 1}`} className="line-remove-button" onClick={() => setLineNumbers((numbers) => numbers.filter((candidate) => candidate !== number))} type="button">×</button>}
        </div>)}</div>
        {lineNumbers.length < 5 && <button className="text-action-button" onClick={() => setLineNumbers((numbers) => [...numbers, nextLine])} type="button">+ Add another item</button>}

        <div className="simple-form-divider" />
        <fieldset className="simple-choice-field"><legend>How will they get it?</legend><div>
          <label><input checked={fulfillment === "collection"} name="handoff_choice" onChange={() => setFulfillment("collection")} type="radio" /><span><strong>Collection</strong><small>Hold it until they collect</small></span></label>
          <label><input checked={fulfillment === "delivery"} name="handoff_choice" onChange={() => setFulfillment("delivery")} type="radio" /><span><strong>Delivery</strong><small>An Agent will take it</small></span></label>
        </div></fieldset>

        <details className="advanced-fields"><summary>Special order options</summary><div><label className="special-choice"><input checked={fulfillment === "consignment"} name="special_handoff" onChange={(event) => setFulfillment(event.target.checked ? "consignment" : "collection")} type="checkbox" /><span>This is a consignment order</span></label><label className="field"><span>Customer note</span><textarea maxLength={2000} name="notes" rows={3} /></label></div></details>

        {state.error && <p className="staff-flash staff-flash-error" role="alert">{state.error}</p>}
        <button className="button button-primary simple-task-submit" disabled={pending || !jurisdiction || visibleItems.length === 0} name="_intent" value="preview">{pending ? "Checking…" : state.preview ? "Check updated total" : "Check total"}</button>
        {!jurisdiction && <p className="field-help">The configured region is unavailable.</p>}
      </section>

      <div className="simple-task-sidebar">{state.preview ? <><OrderPreview preview={state.preview} /><button className="button button-primary order-final-submit" disabled={pending || !state.preview.valid} name="_intent" value="submit">{pending ? "Recording…" : "Record order"}</button></> : <aside className="simple-task-summary simple-summary-placeholder"><p className="eyebrow">Order summary</p><h2>Choose the buyer and goods</h2><p>Check the total to see the authoritative price, license path, and any personal limit before recording the order.</p><ul><li>Orders may be recorded without stock.</li><li>Stock is held later when it is available.</li><li>Nothing leaves inventory until handoff.</li></ul></aside>}</div>
    </form>
  );
}
