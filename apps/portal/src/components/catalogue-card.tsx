import Link from "next/link";

import type { PublicCatalogueItem } from "@/lib/catalogue";
import { formatMinorAmount, formatQuantity } from "@/lib/format";

interface CatalogueCardProps {
  item: PublicCatalogueItem;
  locale: string;
}

export function CatalogueCard({ item, locale }: CatalogueCardProps) {
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

  return (
    <article className="catalogue-card">
      <div className="card-topline">
        <span>{item.category_name}</span>
        <span>{item.item_code}</span>
      </div>

      <div className="card-body">
        <div>
          <h2>
            <Link href={`/catalogue/${item.slug}`}>{item.display_name}</Link>
          </h2>
          <p>{item.description}</p>
        </div>

        <dl className="card-facts">
          <div>
            <dt>Public price</dt>
            <dd>{price ?? "Price by request"}</dd>
          </div>
          <div>
            <dt>Availability</dt>
            <dd>{item.availability_label}</dd>
          </div>
          <div>
            <dt>Control</dt>
            <dd>{item.control_label}</dd>
          </div>
          {minimum && (
            <div>
              <dt>Minimum order</dt>
              <dd>{minimum}</dd>
            </div>
          )}
        </dl>
      </div>

      <div className="card-footer">
        <p>{item.requirement_summary}</p>
        <Link className="text-link" href={`/catalogue/${item.slug}`}>
          View registry entry <span aria-hidden="true">→</span>
        </Link>
      </div>
    </article>
  );
}
