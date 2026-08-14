"use client";

import { useMemo, useState } from "react";

import { configurePriceBindingAction } from "@/app/staff/launch/actions";
import type { LaunchWorkspace } from "@/lib/launch-workspace";
import type { PricePreviewOptions } from "@/lib/price-preview";

type BindingType = "party" | "license_class" | "dealer_type" | "jurisdiction" | "channel_default";

const labels: Record<BindingType, string> = {
  party: "One business",
  license_class: "One license type",
  dealer_type: "One business type",
  jurisdiction: "One region",
  channel_default: "All orders in a channel",
};

export function PriceBindingForm({ preview, workspace }: { preview: PricePreviewOptions; workspace: LaunchWorkspace }) {
  const [binding, setBinding] = useState<BindingType>("party");
  const [targetLabel, setTargetLabel] = useState("Choose a business");
  const [channel, setChannel] = useState("staff_assisted_business");
  const [scheduleId, setScheduleId] = useState("");
  const [itemId, setItemId] = useState("");
  const targets = useMemo(() => {
    if (binding === "party") return workspace.price_targets.parties;
    if (binding === "license_class") return workspace.price_targets.license_classes;
    if (binding === "dealer_type") return workspace.price_targets.dealer_types;
    if (binding === "jurisdiction") return workspace.price_targets.jurisdictions;
    return [];
  }, [binding, workspace.price_targets]);
  const selectedRule = useMemo(() => preview.rules.find((rule) =>
    rule.schedule_id === scheduleId && rule.item_id === itemId,
  ), [itemId, preview.rules, scheduleId]);
  const selectedItem = preview.items.find((item) => item.id === itemId);
  const displayAmount = binding === "channel_default" && channel === "direct_individual"
    ? selectedRule?.direct_amount_minor
    : selectedRule?.amount_minor;

  return (
    <form action={configurePriceBindingAction} className="guided-price-form">
      <input name="priority" type="hidden" value="0" />
      <input name="reason" type="hidden" value="Price rule published through guided pricing workspace." />
      <section className="order-intake-step">
        <div className="order-step-number">1</div>
        <div className="order-step-content">
          <p className="eyebrow">Who receives this price?</p>
          <h2>Choose who gets this price.</h2>
          <label className="field order-primary-field">
            <span>Price applies to</span>
            <select name="binding_type" onChange={(event) => { setBinding(event.target.value as BindingType); setTargetLabel("Choose a target"); }} value={binding}>
              {(Object.keys(labels) as BindingType[]).map((value) => <option key={value} value={value}>{labels[value]}</option>)}
            </select>
          </label>
          {binding === "channel_default" ? (
            <label className="field order-primary-field">
              <span>Sales channel</span>
              <select name="channel_code" onChange={(event) => { setChannel(event.target.value); setTargetLabel(event.target.selectedOptions[0]?.text ?? "Sales channel"); }} value={channel}>
                <option value="staff_assisted_business">Licensed business orders</option>
                <option value="direct_individual">Direct individual orders</option>
              </select>
            </label>
          ) : (
            <label className="field order-primary-field">
              <span>{labels[binding]}</span>
              <select defaultValue="" name="target_id" onChange={(event) => setTargetLabel(event.target.selectedOptions[0]?.text ?? "Selected target")} required>
                <option disabled value="">Choose a target</option>
                {targets.map((target) => <option key={target.id} value={target.id}>{target.label}</option>)}
              </select>
            </label>
          )}
        </div>
      </section>
      <section className="order-intake-step">
        <div className="order-step-number">2</div>
        <div className="order-step-content">
          <p className="eyebrow">Which schedule applies?</p>
          <h2>Choose the price schedule.</h2>
          <label className="field order-primary-field">
            <span>Price schedule</span>
            <select name="schedule_id" onChange={(event) => setScheduleId(event.target.value)} required value={scheduleId}>
              <option disabled value="">Choose a schedule</option>
              {workspace.price_schedules.map((schedule) => <option key={schedule.id} value={schedule.id}>{schedule.label} · {schedule.audience}</option>)}
            </select>
          </label>
          <details className="advanced-fields">
            <summary>Optional start and end dates</summary>
            <div>
              <label className="field"><span>Starts</span><input name="effective_from" type="datetime-local" /><small>Blank means now.</small></label>
              <label className="field"><span>Ends</span><input name="effective_until" type="datetime-local" /><small>Blank means no scheduled end.</small></label>
            </div>
          </details>
        </div>
      </section>
      <section className="order-intake-step">
        <div className="order-step-number">3</div>
        <div className="order-step-content">
          <p className="eyebrow">Test before publishing</p>
          <h2>Choose an item and confirm the result.</h2>
          <label className="field order-primary-field"><span>Test item</span><select onChange={(event) => setItemId(event.target.value)} required value={itemId}><option disabled value="">Choose an item</option>{preview.items.map((item) => <option key={item.id} value={item.id}>{item.code} · {item.label}</option>)}</select></label>
        </div>
      </section>
      <section className="price-rule-preview">
        <p className="eyebrow">Resolution preview</p>
        {selectedRule && displayAmount !== null && displayAmount !== undefined ? <><h2>{displayAmount.toLocaleString()} {selectedRule.currency_code}</h2><p><strong>{selectedItem?.label}</strong> for {targetLabel} matches this {labels[binding].toLowerCase()} rule.</p>{binding === "channel_default" && channel === "direct_individual" && <p>The displayed result includes the database-configured direct-customer multiplier.</p>}<p>More-specific existing rules can still override this price. Every order shows its final authoritative source before submission.</p></> : <><h2>No price to publish yet</h2><p>Choose a schedule and an item that has a rule in that schedule. Publishing stays disabled until an exact amount can be previewed.</p></>}
      </section>
      <button className="button button-primary" disabled={!selectedRule} type="submit">Publish price rule</button>
    </form>
  );
}
