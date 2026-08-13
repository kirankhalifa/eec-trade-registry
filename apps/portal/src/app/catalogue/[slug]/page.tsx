import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";

import { CatalogueUnavailable } from "@/components/catalogue-unavailable";
import { getPublicCatalogueItem } from "@/lib/catalogue";
import { getDefaultLocale } from "@/lib/env";
import { formatMinorAmount, formatQuantity } from "@/lib/format";

export const dynamic = "force-dynamic";

interface CatalogueItemPageProps {
  params: Promise<{ slug: string }>;
}

export async function generateMetadata({
  params,
}: CatalogueItemPageProps): Promise<Metadata> {
  const { slug } = await params;
  const result = await getPublicCatalogueItem(slug);
  if (!result.ok || !result.data) {
    return {
      title: "Catalogue entry",
      description: "View current public trade terms and purchasing requirements from the authoritative registry.",
    };
  }

  return {
    title: result.data.display_name,
    description: result.data.description,
  };
}

export default async function CatalogueItemPage({
  params,
}: CatalogueItemPageProps) {
  const { slug } = await params;
  const result = await getPublicCatalogueItem(slug);

  if (!result.ok) {
    return (
      <main className="detail-main">
        <CatalogueUnavailable notConfigured={result.code === "not_configured"} />
      </main>
    );
  }

  if (result.data === null) {
    notFound();
  }

  const item = result.data;
  const locale = getDefaultLocale();
  const price = formatMinorAmount(
    item.price_amount_minor,
    item.currency_symbol,
    item.currency_symbol_position,
    item.minor_unit_scale,
    locale,
  );
  const minimum = formatQuantity(
    item.bulk_minimum,
    item.unit_symbol,
    locale,
  );
  const increment = formatQuantity(
    item.order_increment,
    item.unit_symbol,
    locale,
  );

  return (
    <main className="detail-main">
      <Link className="back-link" href="/">
        <span aria-hidden="true">←</span> Return to catalogue
      </Link>

      <article className="registry-entry">
        <header>
          <p className="eyebrow">
            {item.category_name} · {item.item_code}
          </p>
          <h1>{item.display_name}</h1>
          <p className="registry-description">{item.description}</p>
        </header>

        <section className="entry-status" aria-label="Catalogue status">
          <div>
            <span>Availability</span>
            <strong>{item.availability_label}</strong>
            <p>{item.availability_description}</p>
          </div>
          <div>
            <span>Control</span>
            <strong>{item.control_label}</strong>
            <p>{item.control_description}</p>
          </div>
          <div>
            <span>Public price</span>
            <strong>{price ?? "By request"}</strong>
            <p>Final eligibility and terms are confirmed when ordering.</p>
          </div>
        </section>

        <section className="entry-requirements">
          <div>
            <p className="eyebrow">Purchasing requirements</p>
            <h2>{item.requirement_summary}</h2>
          </div>
          <dl>
            {minimum && (
              <div>
                <dt>Minimum order</dt>
                <dd>{minimum}</dd>
              </div>
            )}
            <div>
              <dt>Order increment</dt>
              <dd>{increment}</dd>
            </div>
            <div>
              <dt>Unit</dt>
              <dd>{item.unit_name}</dd>
            </div>
          </dl>
        </section>

        {item.tags.length > 0 && (
          <ul className="tag-list" aria-label="Catalogue tags">
            {item.tags.map((tag) => (
              <li key={tag}>{tag}</li>
            ))}
          </ul>
        )}

        <footer>
          <p>
            This entry was projected from the authoritative registry. It does
            not expose exact stock or establish purchase eligibility.
          </p>
        </footer>
      </article>
    </main>
  );
}
