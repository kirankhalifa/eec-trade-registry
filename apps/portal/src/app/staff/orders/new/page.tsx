import Link from "next/link";

import { GuidedOrderForm } from "@/components/guided-order-form";
import { StaffAccessDenied } from "@/components/staff-access-denied";
import { getLaunchWorkspace } from "@/lib/launch-workspace";
import { requireStaffSession } from "@/lib/staff-auth";

export const dynamic = "force-dynamic";

export default async function NewStaffOrderPage() {
  const { client } = await requireStaffSession();
  const result = await getLaunchWorkspace(client);
  if (!result.ok && result.denied) return <main className="staff-main"><StaffAccessDenied /></main>;
  if (!result.ok) return <main className="staff-main"><section className="notice-panel"><h1>Order intake unavailable</h1><p>No fallback business state was used.</p></section></main>;
  if (!result.data.capabilities.can_create_order) return <main className="staff-main"><StaffAccessDenied /></main>;

  return (
    <main className="staff-main staff-order-intake-main">
      <header className="staff-page-header">
        <div>
          <p className="eyebrow">Guided order intake</p>
          <h1>New order</h1>
          <p>Choose the customer, add the goods, review the authoritative price and quota result, then submit.</p>
        </div>
        <Link className="button button-secondary" href="/staff/orders">Back to orders</Link>
      </header>
      <GuidedOrderForm workspace={result.data} />
    </main>
  );
}
