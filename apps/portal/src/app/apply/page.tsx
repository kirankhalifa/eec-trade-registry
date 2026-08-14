import type { Metadata } from "next";

import { ApplicationForms } from "@/app/apply/application-forms";
import { getApplicationOptions } from "@/lib/license-application";
import { createServerSupabaseClient } from "@/lib/supabase-server";

export const dynamic = "force-dynamic";
export const metadata: Metadata = {
  title: "Apply or renew",
  description: "Apply for configured East Empire Company trade authority or request renewal of an existing license.",
};

export default async function ApplyPage() {
  const options = await getApplicationOptions(await createServerSupabaseClient());
  return (
    <main>
      <section className="hero">
        <div>
          <p className="eyebrow">Trade registry intake</p>
          <h1>Apply for trade authority</h1>
          <p>
            Start a new application, renew an existing LIC reference, or check a
            submitted review. No login or email is required.
          </p>
        </div>
      </section>
      {options ? (
        <ApplicationForms options={options} />
      ) : (
        <section className="notice-panel">
          <h2>Applications are temporarily unavailable</h2>
          <p>No fallback form is used while the authoritative registry is unavailable.</p>
        </section>
      )}
    </main>
  );
}
