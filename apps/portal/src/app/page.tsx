import type { Metadata } from "next";
import Link from "next/link";

import { CatalogueCard } from "@/components/catalogue-card";
import { CatalogueFilter } from "@/components/catalogue-filter";
import { CatalogueUnavailable } from "@/components/catalogue-unavailable";
import { RelativeTime } from "@/components/relative-time";
import { UiIcon } from "@/components/ui-icon";
import {
  getPublicCatalogue,
  getPublicCatalogueCategories,
} from "@/lib/catalogue";
import { getDefaultLocale, getInstitutionName } from "@/lib/env";
import { parseCatalogueQuery } from "@/lib/query";

export const revalidate = 60;
export const metadata: Metadata = {
  title: "Trade catalogue",
  description: "Browse the East Empire Company's official public catalogue, current purchasing terms, and controlled-trade requirements.",
};

interface CataloguePageProps {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}

export default async function CataloguePage({
  searchParams,
}: CataloguePageProps) {
  const query = parseCatalogueQuery(await searchParams);
  const [catalogueResult, categoriesResult] = await Promise.all([
    getPublicCatalogue(query),
    getPublicCatalogueCategories(),
  ]);
  const institutionName = getInstitutionName();
  const locale = getDefaultLocale();

  const categories = categoriesResult.ok ? categoriesResult.data : [];
  const generatedAt = catalogueResult.ok
    ? catalogueResult.data[0]?.generated_at ?? null
    : null;

  return (
    <main>
      <section className="hero catalogue-hero">
        <div>
          <p className="eyebrow">Official public catalogue</p>
          <h1>Published trade catalogue</h1>
          <p className="hero-copy">
            Browse goods currently offered by {institutionName}. Open an entry
            for its public terms, purchasing requirements, and control level.
          </p>
          <div className="hero-actions">
            <a className="button button-primary" href="#catalogue-title">
              <UiIcon name="search" /> Browse catalogue
            </a>
            <Link className="button button-secondary" href="/verify">
              <UiIcon name="shield" /> Verify a record
            </Link>
            <Link className="text-link hero-quiet-link" href="/apply">
              Apply for a license <UiIcon name="arrow" size={15} />
            </Link>
          </div>
        </div>
      </section>

      <section className="catalogue-shell" aria-labelledby="catalogue-title">
        <div className="section-heading">
          <div>
            <p className="eyebrow">Public catalogue</p>
            <h2 id="catalogue-title">Published goods</h2>
          </div>
          {generatedAt && <p>Updated <RelativeTime value={generatedAt} /></p>}
        </div>

        <CatalogueFilter categories={categories} query={query} />

        {!catalogueResult.ok ? (
          <CatalogueUnavailable
            notConfigured={catalogueResult.code === "not_configured"}
          />
        ) : catalogueResult.data.length === 0 ? (
          <section className="empty-state" role="status">
            <p className="eyebrow">No matching records</p>
            <h2>No published goods match those filters.</h2>
            <p>Clear the filters or try a broader catalogue search.</p>
          </section>
        ) : (
          <>
            <p className="result-count" aria-live="polite">
              {catalogueResult.data.length} published
              {catalogueResult.data.length === 1 ? " entry" : " entries"}
            </p>
            <div className="catalogue-grid">
              {catalogueResult.data.map((item) => (
                <CatalogueCard key={item.item_code} item={item} locale={locale} />
              ))}
            </div>
          </>
        )}
      </section>
    </main>
  );
}
