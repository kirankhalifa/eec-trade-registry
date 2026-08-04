import Link from "next/link";
import { redirect } from "next/navigation";

import { signInDealerAction } from "@/app/dealer/actions";
import { hasAuthenticatedDealerSession } from "@/lib/dealer-auth";
import { readPublicSupabaseEnvironment } from "@/lib/env";

interface DealerLoginPageProps {
  searchParams: Promise<{ error?: string }>;
}

export default async function DealerLoginPage({
  searchParams,
}: DealerLoginPageProps) {
  const { error } = await searchParams;
  const configured = Boolean(readPublicSupabaseEnvironment());
  if (configured && (await hasAuthenticatedDealerSession())) {
    redirect("/dealer");
  }

  return (
    <main className="staff-login-main dealer-login-main">
      <section className="staff-login-card dealer-login-card">
        <div>
          <p className="eyebrow">Private dealer surface</p>
          <h1>Organization registry</h1>
          <p>
            Sign in with an individually provisioned credential. Every request
            rechecks your active representative grant and the current dealer
            authorization for the organization you represent.
          </p>
        </div>

        {!configured ? (
          <div className="staff-flash staff-flash-error" role="alert">
            Supabase is not configured for this deployment. No fallback data
            source is available.
          </div>
        ) : (
          <form action={signInDealerAction} className="staff-login-form">
            {error === "invalid_credentials" && (
              <div className="staff-flash staff-flash-error" role="alert">
                The supplied credentials could not be verified.
              </div>
            )}
            <label className="field">
              <span>Representative email</span>
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
            Authentication alone grants no organization access. Enrollment,
            recovery, magic links, and secure-link exchange remain controlled
            administrative workflows.
          </p>
        </footer>
      </section>
    </main>
  );
}
