import Link from "next/link";

import { fulfillUniqueAssetAction } from "@/app/staff/launch/actions";
import { StaffAccessDenied } from "@/components/staff-access-denied";
import { StaffNotice } from "@/components/staff-notice";
import { RelativeTime } from "@/components/relative-time";
import { getLaunchWorkspace } from "@/lib/launch-workspace";
import { requireStaffSession } from "@/lib/staff-auth";

interface UniqueFulfillmentPageProps { searchParams: Promise<{ error?: string; notice?: string }> }

export default async function UniqueFulfillmentPage({ searchParams }: UniqueFulfillmentPageProps) {
  const parameters = await searchParams;
  const { client } = await requireStaffSession();
  const result = await getLaunchWorkspace(client);
  if (!result.ok && result.denied) return <main className="staff-main"><StaffAccessDenied /></main>;
  if (!result.ok) return <main className="staff-main"><section className="notice-panel"><h1>Unique handoff unavailable</h1><p>No fallback custody state was used.</p></section></main>;
  if (!result.data.capabilities.can_fulfill_asset) return <main className="staff-main"><StaffAccessDenied /></main>;

  return (
    <main className="staff-main">
      <header className="staff-page-header"><div><p className="eyebrow">Unique-asset handoff</p><h1>Complete a reserved delivery</h1><p>One confirmation consumes the reservation, fulfills the line, and transfers authoritative custody to the customer.</p></div><Link className="button button-secondary" href="/staff/assets">Asset registry</Link></header>
      <StaffNotice error={parameters.error} notice={parameters.notice} />
      <div className="inventory-command-grid">
        {result.data.unique_reservations.map((reservation) => (
          <form action={fulfillUniqueAssetAction} className="inventory-command-form" key={reservation.reservation_id}>
            <p className="eyebrow">{reservation.order_reference}</p>
            <h2>{reservation.asset_reference}</h2>
            <p>Recipient: <strong>{reservation.customer_name}</strong></p>
            <p>Reservation {reservation.reservation_reference} expires <RelativeTime value={reservation.expires_at} />.</p>
            <input name="reservation_id" type="hidden" value={reservation.reservation_id} />
            <input name="reservation_version" type="hidden" value={reservation.reservation_version} />
            <input name="asset_version" type="hidden" value={reservation.asset_version} />
            <label className="field"><span>Accepted handoff evidence</span><input maxLength={500} name="reason" placeholder="Who accepted the asset and where" required /></label>
            <button className="button button-primary">Confirm handoff and custody</button>
          </form>
        ))}
      </div>
      {!result.data.unique_reservations.length && <div className="empty-state"><h2>No unique asset is ready for handoff.</h2><p>Allocate an available asset to an approved unique order line first.</p><Link className="button button-primary" href="/staff/assets">Open asset registry</Link></div>}
    </main>
  );
}
