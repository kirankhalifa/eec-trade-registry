import Link from "next/link";
import { redirect } from "next/navigation";

import { signInWithDiscordAction } from "@/app/staff/actions";
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
              error === "provider_unavailable") && (
              <div className="staff-flash staff-flash-error" role="alert">
                Discord sign-in could not be completed. No staff authority was
                granted or changed.
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
            There is no staff email/password form. A successful Discord sign-in
            grants no access unless the linked Supabase identity has an active
            staff assignment.
          </p>
        </footer>
      </section>
    </main>
  );
}
