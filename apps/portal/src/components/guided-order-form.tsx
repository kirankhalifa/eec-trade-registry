"use client";

import { useActionState, useMemo, useState } from "react";

import { guidedTradeOrderAction } from "@/app/staff/launch/actions";
import type { LaunchWorkspace } from "@/lib/launch-workspace";
import type { GuidedOrderState, TradeOrderPreview } from "@/lib/order-preview";
import { REGISTRY_CONFIG } from "@/lib/registry-config";

const initialState: GuidedOrderState = {};

function amount(value: number | null, currency: string | null) {
  return value === null
    ? "Price not configured"
    : `${new Intl.NumberFormat().format(value)} ${currency ?? REGISTRY_CONFIG.currency.code}`;
}
function OrderPreview({ preview }: { preview: TradeOrderPreview }) {
  return (
    <section className="order-intake-preview" aria-live="polite">
      <header>
        <div>
          <p className="eyebrow">Review before submission</p>
          <h2>{preview.channel_label}</h2>
        </div>
        <strong className={preview.valid ? "preview-ready" : "preview-blocked"}>
          {preview.valid ? "Ready" : "Needs attention"}
        </strong>
      </header>
      <div className="order-preview-lines">
        {preview.lines.map((line) => (
          <article key={line.item_id}>
            <div>
              <code>{line.item_code}</code>
              <h3>{line.item_name}</h3>
              <p>{line.quantity} {line.unit ?? "units"}</p>
            </div>
            <dl>
              <div><dt>Unit price</dt><dd>{amount(line.unit_price_minor, line.currency_code)}</dd></div>
              <div><dt>Price source</dt><dd>{line.price_source}</dd></div>
              {line.multiplier_basis_points !== null && line.multiplier_basis_points !== 10000 && (
                <div><dt>Multiplier</dt><dd>{line.multiplier_basis_points / 10000}×</dd></div>
              )}
              {line.weekly_limit !== null && (
                <div><dt>Personal limit</dt><dd>{line.weekly_remaining} of {line.weekly_limit} remaining before this order</dd></div>
              )}
            </dl>
          </article>
        ))}
      </div>
      <div className="order-preview-total">
        <span>Expected total</span>
        <strong>{amount(preview.total_amount_minor, preview.currency_code)}</strong>
      </div>
      {preview.warnings.map((warning) => <p className="staff-flash staff-flash-error" key={warning}>{warning}</p>)}
      <p className="order-preview-policy">{preview.reservation_message}</p>
    </section>
  );
}

export function GuidedOrderForm({ workspace }: { workspace: LaunchWorkspace }) {
  const [channel, setChannel] = useState<"staff_assisted_business" | "direct_individual">("staff_assisted_business");
  const [directMode, setDirectMode] = useState<"existing" | "new">(
    workspace.direct_customers.length ? "existing" : "new",
  );
  const [lineCount, setLineCount] = useState(1);
  const [state, action, pending] = useActionState(guidedTradeOrderAction, initialState);
  const jurisdiction = workspace.jurisdictions.find(
    (item) => item.code === REGISTRY_CONFIG.jurisdiction.code,
  );
  const visibleItems = useMemo(
    () => channel === "direct_individual"
      ? workspace.items.filter((item) => item.direct_allowed)
      : workspace.items,
    [channel, workspace.items],
  );
  const businessOptions = workspace.businesses.flatMap((business) =>
    business.licenses.map((license) => ({
      id: license.id,
      label: `${business.party_name} · ${license.class} · ${license.reference}`,
      value: `${business.party_id}|${business.dealer_authorization_id}|${license.id}|${business.jurisdiction_id}`,
    })),
  );

  return (
    <form action={action} className="guided-order-intake">
      <input name="channel" type="hidden" value={channel} />
      <input name="reason" type="hidden" value="Guided staff order intake." />
      <section className="order-intake-step">
        <div className="order-step-number">1</div>
        <div className="order-step-content">
          <p className="eyebrow">Who is buying?</p>
          <h2>Choose the sales path.</h2>
          <div className="choice-buttons">
            <button aria-pressed={channel === "staff_assisted_business"} onClick={() => setChannel("staff_assisted_business")} type="button">
              <strong>Licensed business</strong><small>Wholesale or licensed terms</small>
            </button>
            <button aria-pressed={channel === "direct_individual"} onClick={() => setChannel("direct_individual")} type="button">
              <strong>Individual customer</strong><small>Automatic 3× premium and personal limit</small>
            </button>
          </div>

          {channel === "staff_assisted_business" ? (
            businessOptions.length ? (
              <label className="field order-primary-field">
                <span>Business and active license</span>
                <select defaultValue="" name="business_key" required>
                  <option disabled value="">Choose a licensed business</option>
                  {businessOptions.map((option) => <option key={option.id} value={option.value}>{option.label}</option>)}
                </select>
              </label>
            ) : (
              <div className="empty-state compact-empty-state">
                <h3>No licensed business can order yet.</h3>
                <p>Issue an active license linked to an authorized business before entering a wholesale order.</p>
              </div>
            )
          ) : (
            <div className="direct-customer-branch">
              {workspace.direct_customers.length > 0 && (
                <div className="inline-choice-buttons">
                  <button aria-pressed={directMode === "existing"} onClick={() => setDirectMode("existing")} type="button">Returning customer</button>
                  <button aria-pressed={directMode === "new"} onClick={() => setDirectMode("new")} type="button">New customer</button>
                </div>
              )}
              {directMode === "existing" && workspace.direct_customers.length ? (
                <label className="field order-primary-field">
                  <span>Returning customer</span>
                  <select defaultValue="" name="direct_customer_id" required>
                    <option disabled value="">Choose a customer</option>
                    {workspace.direct_customers.map((customer) => <option key={customer.party_id} value={customer.party_id}>{customer.name} · {customer.reference}</option>)}
                  </select>
                </label>
              ) : (
                <div className="staff-form-grid">
                  <input name="direct_customer_id" type="hidden" value="" />
                  <label className="field"><span>Customer name</span><input maxLength={200} name="new_customer_name" required /></label>
                  <label className="field"><span>Discord or contact label</span><input maxLength={300} name="contact_label" /></label>
                </div>
              )}
              {jurisdiction ? (
                <div className="derived-choice">
                  <span>Region</span><strong>{jurisdiction.label}</strong><small>Assigned automatically</small>
                  <input name="jurisdiction_id" type="hidden" value={jurisdiction.id} />
                </div>
              ) : (
                <p className="staff-flash staff-flash-error">The configured region is unavailable.</p>
              )}
            </div>
          )}
        </div>
      </section>

      <section className="order-intake-step">
        <div className="order-step-number">2</div>
        <div className="order-step-content">
          <p className="eyebrow">What do they need?</p>
          <h2>Add the goods.</h2>
          <div className="guided-order-lines">
            {Array.from({ length: lineCount }, (_, index) => index + 1).map((number) => (
              <div className="guided-order-line" key={number}>
                <label className="field">
                  <span>{number === 1 ? "Item" : `Item ${number}`}</span>
                  <select defaultValue="" name={`item_id_${number}`} required>
                    <option disabled value="">Choose goods</option>
                    {visibleItems.map((item) => (
                      <option key={item.id} value={item.id}>
                        {item.code} · {item.name}
                        {channel === "direct_individual" && item.direct_weekly_limit !== null
                          ? ` · ${item.direct_weekly_limit}/week`
                          : ""}
                      </option>
                    ))}
                  </select>
                </label>
                <label className="field quantity-field"><span>Quantity</span><input defaultValue="1" min="0.001" name={`quantity_${number}`} required step="0.001" type="number" /></label>
              </div>
            ))}
          </div>
          {lineCount < 5 && <button className="button button-secondary" onClick={() => setLineCount((count) => count + 1)} type="button">+ Add another item</button>}
        </div>
      </section>

      <section className="order-intake-step">
        <div className="order-step-number">3</div>
        <div className="order-step-content">
          <p className="eyebrow">How will it be handed over?</p>
          <h2>Choose fulfillment.</h2>
          <label className="field order-primary-field">
            <span>Fulfillment method</span>
            <select defaultValue="collection" name="fulfillment_mode">
              <option value="collection">Customer collection</option>
              <option value="delivery">Company delivery</option>
              <option value="consignment">Consignment</option>
            </select>
          </label>
          <details className="advanced-fields">
            <summary>Optional customer note</summary>
            <div><label className="field"><span>Order note</span><textarea maxLength={2000} name="notes" rows={3} /></label></div>
          </details>
        </div>
      </section>

      {state.error && <p className="staff-flash staff-flash-error" role="alert">{state.error}</p>}
      <button className="button button-primary order-preview-button" disabled={pending || (channel === "staff_assisted_business" && !businessOptions.length) || (channel === "direct_individual" && !jurisdiction)} name="_intent" value="preview">
        {pending ? "Checking…" : "Review order"}
      </button>

      {state.preview && (
        <>
          <OrderPreview preview={state.preview} />
          <button className="button button-primary order-submit-button" disabled={pending || !state.preview.valid} name="_intent" value="submit">
            {pending ? "Submitting…" : "Submit order"}
          </button>
        </>
      )}
    </form>
  );
}
