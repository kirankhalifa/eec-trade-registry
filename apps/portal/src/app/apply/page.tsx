import { ApplicationForms } from "@/app/apply/application-forms";
import { getApplicationOptions } from "@/lib/license-application";
import { createServerSupabaseClient } from "@/lib/supabase-server";

export const dynamic = "force-dynamic";

export default async function ApplyPage() {
  const options = await getApplicationOptions(await createServerSupabaseClient());
  return (
    <main>
      <section className="hero">
        <div>
          <p className="eyebrow">Trade registry intake</p>
          <h1>License applications and renewals</h1>
          <p>
            Apply for configured trade authority or request renewal of an existing
            EEC license. Submission creates a review case, not an automatic license.
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
