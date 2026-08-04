import Link from "next/link";
import { redirect } from "next/navigation";

import { signInAction } from "@/app/staff/actions";
import { readPublicSupabaseEnvironment } from "@/lib/env";
import { hasStaffSession } from "@/lib/staff-auth";

interface StaffLoginPageProps {
  searchParams: Promise<{ error?: string }>;
}

export default async function StaffLoginPage({
  searchParams,
}: StaffLoginPageProps) {
  const { error } = await searchParams;
  const configured = Boolean(readPublicSupabaseEnvironment());
  if (configured && (await hasStaffSession())) {
    redirect("/staff");
  }

  return (
    <main className="staff-login-main">
      <section className="staff-login-card">
        <div>
          <p className="eyebrow">Restricted staff surface</p>
          <h1>Catalogue operations</h1>
          <p>
            Sign in with an individually provisioned Supabase Auth account.
            Authentication is followed by a database role-assignment check for
            every read and write.
          </p>
        </div>

        {!configured ? (
          <div className="staff-flash staff-flash-error" role="alert">
            Supabase is not configured for this deployment. No fallback data
            source is available.
          </div>
        ) : (
          <form action={signInAction} className="staff-login-form">
            {error === "invalid_credentials" && (
              <div className="staff-flash staff-flash-error" role="alert">
                The supplied credentials could not be verified.
              </div>
            )}
            <label className="field">
              <span>Staff email</span>
              <input
                autoComplete="username"
                inputMode="email"
                name="email"
                required
                type="email"
              />
            </label>
            <label className="field">
              <span>Password</span>
              <input
                autoComplete="current-password"
                name="password"
                required
                type="password"
              />
            </label>
            <button className="button button-primary" type="submit">
              Sign in
            </button>
          </form>
        )}

        <footer>
          <Link className="back-link" href="/">
            ← Return to the public catalogue
          </Link>
          <p>
            Account creation, recovery, MFA, and production identity-provider
            policy remain administrative concerns and are not exposed here.
          </p>
        </footer>
      </section>
    </main>
  );
}
