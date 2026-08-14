import type { Metadata } from "next";
import Link from "next/link";

import { ReferenceBlock } from "@/components/reference-block";

export const metadata: Metadata = {
  title: "Catalogue entry withdrawn",
  description:
    "This East Empire Company catalogue entry has been formally withdrawn from public trade.",
  robots: { follow: false, index: false },
};

interface WithdrawnCataloguePageProps {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}

export default async function WithdrawnCataloguePage({
  searchParams,
}: WithdrawnCataloguePageProps) {
  const raw = (await searchParams).slug;
  const slug = (Array.isArray(raw) ? raw[0] : raw)?.slice(0, 120) ?? "withdrawn-entry";

  return (
    <main className="detail-main">
      <Link className="back-link" href="/">
        ← Return to catalogue
      </Link>
      <section className="notice-panel withdrawn-entry">
        <p className="eyebrow">Formal registry status</p>
        <h1>Catalogue entry withdrawn.</h1>
        <p>
          This record was previously public but is no longer offered through the
          catalogue. It has not been silently deleted, and this URL returns the
          permanent HTTP 410 status used for withdrawn records.
        </p>
        <ReferenceBlock label="Former catalogue slug" reference={slug} status="Withdrawn" />
      </section>
    </main>
  );
}
