import Link from "next/link";
import { redirect } from "next/navigation";

import { retryStaffAccessRequestAction, signOutAction } from "@/app/staff/actions";
import { getDefaultLocale } from "@/lib/env";
import { getMyStaffAccessState } from "@/lib/staff-access";
import { requireStaffSession } from "@/lib/staff-auth";

export const dynamic = "force-dynamic";

const headings = {
  blocked: "Access is blocked",
  denied: "Access was not approved",
  pending: "Owner approval is pending",
  unregistered: "Finish creating your request",
} as const;

export default async function PendingStaffAccessPage() {
  const { client } = await requireStaffSession();
  const result = await getMyStaffAccessState(client);
  if (result.ok && result.data.state === "authorized") redirect("/staff/dashboard");

  const state = result.ok ? result.data.state : "unregistered";
  const pendingState = state === "authorized" ? "unregistered" : state;
  const locale = getDefaultLocale();

  return <main className="staff-login-main">
    <section className="staff-login-card">
      <div>
        <p className="eyebrow">Discord identity confirmed</p>
        <h1>{headings[pendingState]}</h1>
        {pendingState === "pending" && <p>Your request is now visible in the owner dashboard. You do not have staff access until the owner approves you as an Agent.</p>}
        {pendingState === "denied" && <p>The owner denied this staff-access request. Signing in again will not bypass that decision; contact the owner if it should be reconsidered.</p>}
        {pendingState === "blocked" && <p>This Discord identity is blocked from staff access. Only the owner can reverse that decision.</p>}
        {pendingState === "unregistered" && <p>Your authenticated identity has not yet been placed in the review queue. Retry the registration below.</p>}
      </div>

      {result.ok && <dl className="staff-item-facts">
        <div><dt>Discord identity</dt><dd>{result.data.display_name ?? "Confirmed"}</dd></div>
        <div><dt>Request state</dt><dd>{result.data.state}</dd></div>
        {result.data.requested_at && <div><dt>Requested</dt><dd>{new Date(result.data.requested_at).toLocaleString(locale)}</dd></div>}
        {result.data.reviewed_at && <div><dt>Reviewed</dt><dd>{new Date(result.data.reviewed_at).toLocaleString(locale)}</dd></div>}
      </dl>}

      {result.ok && result.data.review_reason && <div className="notice-panel"><strong>Owner note</strong><p>{result.data.review_reason}</p></div>}

      <div className="staff-button-row">
        {(pendingState === "unregistered" || !result.ok) && <form action={retryStaffAccessRequestAction}><button className="button button-primary">Create access request</button></form>}
        <form action={signOutAction}><button className="button button-secondary">Sign out</button></form>
        <Link className="button button-secondary" href="/">Public catalogue</Link>
      </div>
    </section>
  </main>;
}
