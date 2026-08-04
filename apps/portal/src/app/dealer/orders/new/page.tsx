import Link from "next/link";

import { submitDealerOrderAction } from "@/app/dealer/orders/actions";
import { DealerAccessDenied } from "@/components/dealer-access-denied";
import { OrderNotice } from "@/components/order-notice";
import { requireDealerSession } from "@/lib/dealer-auth";
import { getDealerOrderReferenceData } from "@/lib/orders";

interface NewDealerOrderPageProps {
  searchParams: Promise<{ error?: string; notice?: string }>;
}

export default async function NewDealerOrderPage({
  searchParams,
}: NewDealerOrderPageProps) {
  const parameters = await searchParams;
  const { client } = await requireDealerSession();
  const result = await getDealerOrderReferenceData(client);
  if (!result.ok && result.code === "access_denied") {
    return (
      <main className="dealer-main">
        <DealerAccessDenied />
      </main>
    );
  }
  if (!result.ok) {
    return (
      <main className="dealer-main">
        <section className="notice-panel">
          <p className="eyebrow">Order desk unavailable</p>
          <h1>The requisition form could not be loaded</h1>
          <p>No secondary catalogue was used.</p>
        </section>
      </main>
    );
  }

  const representations = result.data.representations;
  return (
    <main className="staff-editor-main dealer-main">
      <Link className="back-link" href="/dealer/orders">
        ← Back to orders
      </Link>
      <header className="staff-editor-header">
        <p className="eyebrow">Dealer order desk · new requisition</p>
        <h1>Submit wholesale order</h1>
        <p>
          Prices begin pending and stock is not checked at submission. Every line is
          revalidated and routed to staff review in Supabase.
        </p>
      </header>

      <OrderNotice error={parameters.error} notice={parameters.notice} />

      <form action={submitDealerOrderAction} className="staff-form">
        <fieldset className="staff-fieldset">
          <legend>Ordering authority</legend>
          <div className="staff-form-grid">
            <label className="field">
              <span>Represented organization</span>
              <select name="ordering_party_id" required>
                {representations.map((representation) => (
                  <option key={representation.party_id} value={representation.party_id}>
                    {representation.party_name}
                  </option>
                ))}
              </select>
            </label>
            <label className="field">
              <span>Dealer authorization</span>
              <select name="dealer_authorization_id" required>
                {representations.flatMap((representation) =>
                  representation.dealer_authorizations.map((authorization) => (
                    <option key={authorization.id} value={authorization.id}>
                      {authorization.public_reference} · {authorization.jurisdiction_label}
                    </option>
                  )),
                )}
              </select>
            </label>
            <label className="field">
              <span>License (optional)</span>
              <select name="license_id">
                <option value="">No license attached; staff review required</option>
                {representations.flatMap((representation) =>
                  representation.licenses.map((license) => (
                    <option key={license.id} value={license.id}>
                      {license.public_reference} · {license.class_label}
                    </option>
                  )),
                )}
              </select>
            </label>
            <label className="field">
              <span>Fulfillment mode</span>
              <select name="fulfillment_mode" required>
                <option value="collection">Collection</option>
                <option value="delivery">Delivery</option>
                <option value="consignment">Consignment request</option>
              </select>
            </label>
          </div>
        </fieldset>

        <fieldset className="staff-fieldset">
          <legend>Requested goods</legend>
          <p className="field-help">Use one row per item. Blank rows are ignored.</p>
          <div className="order-line-entry-grid">
            {Array.from({ length: 5 }, (_, index) => (
              <div className="order-line-entry" key={index}>
                <label className="field">
                  <span>Item {index + 1}</span>
                  <select name="item_ids" required={index === 0}>
                    <option value="">Select an item</option>
                    {result.data.items.map((item) => (
                      <option key={item.id} value={item.id}>
                        {item.item_code} · {item.display_name} · {item.control_label}
                      </option>
                    ))}
                  </select>
                </label>
                <label className="field">
                  <span>Quantity</span>
                  <input
                    min="0.001"
                    name="quantities"
                    required={index === 0}
                    step="0.001"
                    type="number"
                  />
                </label>
              </div>
            ))}
          </div>
        </fieldset>

        <fieldset className="staff-fieldset">
          <legend>Request context</legend>
          <label className="field">
            <span>Dealer notes</span>
            <textarea maxLength={2000} name="dealer_notes" rows={4} />
          </label>
          <label className="field">
            <span>Submission reason</span>
            <textarea maxLength={500} minLength={1} name="reason" required rows={3} />
          </label>
        </fieldset>

        <div className="staff-button-row">
          <button className="button button-primary" type="submit">
            Submit requisition
          </button>
          <Link className="button button-secondary" href="/dealer/orders">
            Cancel
          </Link>
        </div>
      </form>
    </main>
  );
}
