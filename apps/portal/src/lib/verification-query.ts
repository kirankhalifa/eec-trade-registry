const MAX_REFERENCE_LENGTH = 128;

type SearchParams = Record<string, string | string[] | undefined>;

function firstValue(value: string | string[] | undefined): string | null {
  return Array.isArray(value) ? value[0] ?? null : value ?? null;
}

export function normalizeVerificationReference(value: string | null): string | null {
  const normalized = value?.trim().replace(/\s+/g, " ").toUpperCase() ?? "";
  return normalized ? normalized.slice(0, MAX_REFERENCE_LENGTH) : null;
}

export function parseVerificationReference(params: SearchParams): string | null {
  return normalizeVerificationReference(firstValue(params.reference));
}
