import Link from "next/link";

import { signOutAction } from "@/app/staff/actions";
import {
  authorizeTransferAction,
  cancelTransferAction,
  createTransferAction,
  dispatchTransferAction,
  disputeTransferAction,
  receiveTransferAction,
} from "@/app/staff/transfers/actions";
import { StaffAccessDenied } from "@/components/staff-access-denied";
import { TransferNotice } from "@/components/transfer-notice";
import { getDefaultLocale } from "@/lib/env";
import { requireStaffSession } from "@/lib/staff-auth";
import { getStaffTransferWorkspace, type TransferWorkspace } from "@/lib/transfers";

interface StaffTransfersPageProps {
  searchParams: Promise<{ error?: string; notice?: string }>;
}

function quantity(value: number) {
  return new Intl.NumberFormat(undefined, { maximumFractionDigits: 3 }).format(value);
}

function TransferCommand({
  action,
  button,
  transfer,
}: {
  action: (formData: FormData) => Promise<void>;
  button: string;
  transfer: TransferWorkspace["transfers"][number];
}) {
  return (
    <form action={action} className="inventory-command-form">
      <input name="stock_transfer_id" type="hidden" value={transfer.id} />
      <input name="expected_version" type="hidden" value={transfer.version} />
      <label className="field">
        <span>Audit reason / evidence</span>
        <input maxLength={500} name="reason" required />
      </label>
      <button className="button button-secondary" type="submit">{button}</button>
    </form>
  );
}

export default async function StaffTransfersPage({ searchParams }: StaffTransfersPageProps) {
  const parameters = await searchParams;
  const { client } = await requireStaffSession();
  const result = await getStaffTransferWorkspace(client);
  if (!result.ok && result.code === "access_denied") {
    return <main className="staff-main"><StaffAccessDenied /></main>;
  }
  if (!result.ok) {
    return (
      <main className="staff-main"><section className="notice-panel">
        <h1>Transfer desk unavailable</h1>
        <p>No fallback custody state was used and no authoritative record was changed.</p>
      </section></main>
    );
  }

  const workspace = result.data;
  const locale = getDefaultLocale();
  const inTransit = workspace.transfers.filter((item) =>
    item.status === "dispatched" || item.status === "disputed"
  ).length;
  const open = workspace.transfers.filter((item) =>
    !["received", "cancelled"].includes(item.status)
  ).length;

  return (
    <main className="staff-main">
      <header className="staff-page-header">
        <div>
          <p className="eyebrow">Authenticated staff - chain of custody</p>
          <h1>Warehouse transfers</h1>
          <p>
            Request, authorize, dispatch, dispute, and receive fungible stock without losing
            it between warehouses. Dispatch and receipt post separate balanced movements.
          </p>
        </div>
        <div className="staff-button-row">
          <Link className="button button-secondary" href="/staff/inventory">Inventory desk</Link>
          <Link className="button button-secondary" href="/staff/fulfillment">Fulfillment</Link>
          <Link className="button button-secondary" href="/staff/assets">Serialized assets</Link>
          <form action={signOutAction}><button className="button button-primary" type="submit">Sign out</button></form>
        </div>
      </header>

      <TransferNotice error={parameters.error} notice={parameters.notice} />

      <section className="inventory-summary" aria-label="Transfer totals">
        <article><span>Open</span><strong>{open}</strong></article>
        <article><span>In transit</span><strong>{inTransit}</strong></article>
        <article><span>Received</span><strong>{workspace.transfers.filter((item) => item.status === "received").length}</strong></article>
        <article><span>Accounts</span><strong>{workspace.accounts.length}</strong></article>
      </section>

      <section className="inventory-section">
        <div className="inventory-section-heading">
          <div><p className="eyebrow">Controlled request</p><h2>Create transfer</h2></div>
          <p>The database rejects incompatible items, owners, locations, and same-warehouse routes.</p>
        </div>
        {workspace.accounts.length >= 2 ? (
          <form action={createTransferAction} className="inventory-command-form inventory-receipt-form">
            <label className="field">
              <span>Source account</span>
              <select name="source_inventory_account_id" required>
                <option value="">Choose source stock</option>
                {workspace.accounts.map((account) => (
                  <option key={account.id} value={account.id}>
                    {account.warehouse_name} / {account.location_name} / {account.item_code} / {quantity(account.available)} available
                  </option>
                ))}
              </select>
            </label>
            <label className="field">
              <span>Destination account</span>
              <select name="destination_inventory_account_id" required>
                <option value="">Choose destination stock account</option>
                {workspace.accounts.map((account) => (
                  <option key={account.id} value={account.id}>
                    {account.warehouse_name} / {account.location_name} / {account.item_code}
                  </option>
                ))}
              </select>
            </label>
            <label className="field"><span>Quantity</span><input min="0.001" name="quantity" required step="0.001" type="number" /></label>
            <label className="field"><span>Request reason</span><textarea maxLength={500} name="reason" required rows={3} /></label>
            <button className="button button-primary" type="submit">Request transfer</button>
          </form>
        ) : <p className="empty-state">At least two compatible physical stock accounts are required.</p>}
      </section>

      <section className="inventory-section">
        <div className="inventory-section-heading">
          <div><p className="eyebrow">Custody queue</p><h2>Transfer register</h2></div>
          <p>Dispatched transfers cannot be cancelled; use dispute and recorded resolution.</p>
        </div>
        <div className="inventory-transaction-list">
          {workspace.transfers.map((transfer) => (
            <article className="inventory-transaction-card" key={transfer.id}>
              <div>
                <span className={`order-status order-status-${transfer.status}`}>{transfer.status}</span>
                <h3>{transfer.public_reference}</h3>
                <p>{transfer.item_code} - {quantity(transfer.quantity)}</p>
                <small>
                  {transfer.source_warehouse_name} / {transfer.source_location_name} to {transfer.destination_warehouse_name} / {transfer.destination_location_name}
                  {" - "}{new Date(transfer.requested_at).toLocaleString(locale)}
                </small>
              </div>
              <div className="inventory-reservation-list">
                {transfer.status === "requested" && transfer.can_authorize && (
                  <TransferCommand action={authorizeTransferAction} button="Authorize" transfer={transfer} />
                )}
                {transfer.status === "authorized" && transfer.can_dispatch && (
                  <TransferCommand action={dispatchTransferAction} button="Dispatch to transit" transfer={transfer} />
                )}
                {transfer.status === "dispatched" && transfer.can_receive && (
                  <>
                    <TransferCommand action={receiveTransferAction} button="Confirm receipt" transfer={transfer} />
                    <TransferCommand action={disputeTransferAction} button="Record discrepancy" transfer={transfer} />
                  </>
                )}
                {transfer.status === "disputed" && transfer.can_receive && (
                  <TransferCommand action={receiveTransferAction} button="Resolve and receive" transfer={transfer} />
                )}
                {["requested", "authorized"].includes(transfer.status) && transfer.can_cancel && (
                  <TransferCommand action={cancelTransferAction} button="Cancel before dispatch" transfer={transfer} />
                )}
              </div>
            </article>
          ))}
        </div>
        {workspace.transfers.length === 0 && <p className="empty-state">No transfer has been requested yet.</p>}
      </section>
    </main>
  );
}
