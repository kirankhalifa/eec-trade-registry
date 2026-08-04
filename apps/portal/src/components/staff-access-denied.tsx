import Link from "next/link";

import { signOutAction } from "@/app/staff/actions";

export function StaffAccessDenied() {
  return (
    <section className="notice-panel staff-access-panel">
      <p className="eyebrow">Authenticated · no catalogue assignment</p>
      <h1>Staff access is not assigned</h1>
      <p>
        Your identity was verified, but authentication alone does not grant
        catalogue authority. Ask an administrator to create an active actor
        profile and catalogue role assignment.
      </p>
      <div className="staff-button-row">
        <form action={signOutAction}>
          <button className="button button-primary" type="submit">
            Sign out
          </button>
        </form>
        <Link className="button button-secondary" href="/">
          Public catalogue
        </Link>
      </div>
    </section>
  );
}
