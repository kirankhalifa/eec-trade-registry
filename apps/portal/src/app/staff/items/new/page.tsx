import Link from "next/link";

import { StaffAccessDenied } from "@/components/staff-access-denied";
import { StaffItemForm } from "@/components/staff-item-form";
import { StaffNotice } from "@/components/staff-notice";
import { readPublicSupabaseEnvironment } from "@/lib/env";
import { requireStaffSession } from "@/lib/staff-auth";
import { getStaffCatalogueReferenceData } from "@/lib/staff-catalogue";

interface NewStaffCatalogueItemPageProps {
  searchParams: Promise<{ error?: string }>;
}

export default async function NewStaffCatalogueItemPage({
  searchParams,
}: NewStaffCatalogueItemPageProps) {
  const { error } = await searchParams;
  if (!readPublicSupabaseEnvironment()) {
    return (
      <main className="staff-main">
        <section className="notice-panel">
          <h1>Supabase is not configured</h1>
          <p>No authoritative catalogue source is available.</p>
        </section>
      </main>
    );
  }
  const { client } = await requireStaffSession();
  const references = await getStaffCatalogueReferenceData(client);
  if (!references.ok && references.code === "access_denied") {
    return (
      <main className="staff-main">
        <StaffAccessDenied />
      </main>
    );
  }
  if (!references.ok) {
    return (
      <main className="staff-main">
        <section className="notice-panel">
          <h1>Catalogue configuration could not be loaded</h1>
          <p>No authoritative data was changed.</p>
        </section>
      </main>
    );
  }

  return (
    <main className="staff-main staff-editor-main">
      <Link className="back-link" href="/staff">
        ← Return to work queue
      </Link>
      <header className="staff-editor-header">
        <p className="eyebrow">New canonical record</p>
        <h1>Create an unpublished item</h1>
        <p>
          This creates one internal source record. It does not publish the item,
          set a price, establish eligibility, or create stock.
        </p>
      </header>
      <StaffNotice error={error} />
      <StaffItemForm references={references.data} />
    </main>
  );
}
