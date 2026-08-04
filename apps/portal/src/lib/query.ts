const MAX_SEARCH_LENGTH = 100;
const CATEGORY_PATTERN = /^[a-z0-9][a-z0-9_-]{0,49}$/;

export interface CatalogueQuery {
  category: string | null;
  search: string | null;
}

type SearchParams = Record<string, string | string[] | undefined>;

function firstValue(value: string | string[] | undefined): string | null {
  return Array.isArray(value) ? value[0] ?? null : value ?? null;
}

export function normalizeSearch(value: string | null): string | null {
  const normalized = value?.trim().replace(/\s+/g, " ") ?? "";
  return normalized ? normalized.slice(0, MAX_SEARCH_LENGTH) : null;
}

export function normalizeCategory(value: string | null): string | null {
  const normalized = value?.trim().toLowerCase() ?? "";
  return CATEGORY_PATTERN.test(normalized) ? normalized : null;
}

export function parseCatalogueQuery(params: SearchParams): CatalogueQuery {
  return {
    category: normalizeCategory(firstValue(params.category)),
    search: normalizeSearch(firstValue(params.q)),
  };
}
