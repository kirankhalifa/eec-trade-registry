import Link from "next/link";

import { signOutDealerAction } from "@/app/dealer/actions";

export function DealerAccessDenied() {
  return (
    <section className="notice-panel staff-access-panel">
      <p className="eyebrow">Authenticated · no active dealer representation</p>
      <h1>Dealer portal access is not assigned</h1>
      <p>
        Your identity was verified, but no current representative grant with
        portal access was found for an actively authorized dealer organization.
        Expired and revoked grants fail closed immediately.
      </p>
      <div className="staff-button-row">
        <form action={signOutDealerAction}>
          <button className="button button-primary" type="submit">
            Sign out
          </button>
        </form>
        <Link className="button button-secondary" href="/verify">
          Public verification
        </Link>
      </div>
    </section>
  );
}
