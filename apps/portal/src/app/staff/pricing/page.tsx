import Link from "next/link";

import { PriceBindingForm } from "@/components/price-binding-form";
import { StaffAccessDenied } from "@/components/staff-access-denied";
import { StaffNotice } from "@/components/staff-notice";
import { getLaunchWorkspace } from "@/lib/launch-workspace";
import { getPricePreviewOptions } from "@/lib/price-preview";
import { requireStaffSession } from "@/lib/staff-auth";

interface PricingPageProps { searchParams: Promise<{ error?: string; notice?: string }> }

export default async function PricingPage({ searchParams }: PricingPageProps) {
  const parameters = await searchParams;
  const { client } = await requireStaffSession();
  const result = await getLaunchWorkspace(client);
  if (!result.ok && result.denied) return <main className="staff-main"><StaffAccessDenied /></main>;
  if (!result.ok) return <main className="staff-main"><section className="notice-panel"><h1>Pricing workspace unavailable</h1><p>No fallback pricing state was used.</p></section></main>;
  if (!result.data.capabilities.can_manage_pricing) return <main className="staff-main"><StaffAccessDenied /></main>;
  const preview = await getPricePreviewOptions(client);
  if (!preview.ok) return <main className="staff-main"><section className="notice-panel"><h1>Pricing workspace unavailable</h1><p>The authoritative preview options could not be loaded.</p></section></main>;
  return (
    <main className="staff-main staff-order-intake-main">
      <header className="staff-page-header"><div><p className="eyebrow">Guided pricing</p><h1>Publish a price rule</h1><p>Choose the audience first. The form then shows only the target that applies to that level.</p></div><Link className="button button-secondary" href="/staff/launch">Quick actions</Link></header>
      <StaffNotice error={parameters.error} notice={parameters.notice} />
      <PriceBindingForm preview={preview.data} workspace={result.data} />
    </main>
  );
}
