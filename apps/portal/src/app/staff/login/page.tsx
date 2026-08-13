import Link from "next/link";
import { redirect } from "next/navigation";

import { signInWithDiscordAction } from "@/app/staff/actions";
import { readPublicSupabaseEnvironment } from "@/lib/env";
import { getMyStaffAccessState } from "@/lib/staff-access";
import { createServerSupabaseClient } from "@/lib/supabase-server";

interface StaffLoginPageProps {
  searchParams: Promise<{ error?: string }>;
}

export default async function StaffLoginPage({
  searchParams,
}: StaffLoginPageProps) {
  const { error } = await searchParams;
  const configured = Boolean(readPublicSupabaseEnvironment());
  if (configured) {
    const client = await createServerSupabaseClient();
    const session = await client.auth.getClaims();
    if (!session.error && typeof session.data?.claims?.sub === "string") {
      const access = await getMyStaffAccessState(client);
      if (access.ok && access.data.state === "authorized") redirect("/staff/dashboard");
      if (access.ok) redirect(`/staff/access/pending?state=${access.data.state}`);
    }
  }

  return (
    <main className="staff-login-main">
      <section className="staff-login-card">
        <div>
          <p className="eyebrow">Restricted staff surface</p>
          <h1>Catalogue operations</h1>
          <p>
            Continue with your individually approved Discord identity. Discord
            proves who you are; Supabase role assignments still authorize every
            staff read and write.
          </p>
        </div>

        {!configured ? (
          <div className="staff-flash staff-flash-error" role="alert">
            Supabase is not configured for this deployment. No fallback data
            source is available.
          </div>
        ) : (
          <form action={signInWithDiscordAction} className="staff-login-form">
            {error === "cancelled" && (
              <div className="staff-flash staff-flash-error" role="alert">
                Discord sign-in was cancelled. No session was created.
              </div>
            )}
            {(error === "exchange_failed" ||
              error === "provider_unavailable" ||
              error === "provider_error" ||
              error === "missing_code") && (
              <div className="staff-flash staff-flash-error" role="alert">
                Discord did not complete the sign-in. Try again and approve the
                identity prompt. If this repeats, the owner should verify the
                Discord OAuth redirect configuration.
              </div>
            )}
            {error === "request_failed" && (
              <div className="staff-flash staff-flash-error" role="alert">
                Your Discord session was created, but the access request could
                not be recorded. The session was closed and no authority was granted.
              </div>
            )}
            <button className="button button-primary" type="submit">
              Continue with Discord
            </button>
          </form>
        )}

        <footer>
          <Link className="back-link" href="/">
            ← Return to the public catalogue
          </Link>
          <p>
            There is no staff email/password form. First-time Discord users enter
            an owner review queue. Approval as an Agent is still required before
            any staff data or command becomes available.
          </p>
        </footer>
      </section>
    </main>
  );
}
