import Link from "next/link";

import type { PublicCatalogueCategory } from "@/lib/catalogue";
import type { CatalogueQuery } from "@/lib/query";

interface CatalogueFilterProps {
  categories: PublicCatalogueCategory[];
  query: CatalogueQuery;
}

export function CatalogueFilter({
  categories,
  query,
}: CatalogueFilterProps) {
  return (
    <form className="catalogue-filter" method="get" role="search">
      <label className="field field-search">
        <span>Search the registry</span>
        <input
          defaultValue={query.search ?? ""}
          maxLength={100}
          name="q"
          placeholder="Item name, code, description, or tag"
          type="search"
        />
      </label>

      <label className="field">
        <span>Category</span>
        <select defaultValue={query.category ?? ""} name="category">
          <option value="">All categories</option>
          {categories.map((category) => (
            <option key={category.code} value={category.code}>
              {category.display_name} ({category.item_count})
            </option>
          ))}
        </select>
      </label>

      <button className="button button-primary" type="submit">
        Search catalogue
      </button>

      {(query.search || query.category) && (
        <Link className="button button-secondary" href="/">
          Clear filters
        </Link>
      )}
    </form>
  );
}
