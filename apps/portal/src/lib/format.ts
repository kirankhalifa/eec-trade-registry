export type SymbolPosition = "prefix" | "suffix";

export function formatMinorAmount(
  amountMinor: number | null,
  symbol: string | null,
  symbolPosition: SymbolPosition | null,
  minorUnitScale: number | null,
  locale: string,
): string | null {
  if (
    amountMinor === null ||
    minorUnitScale === null ||
    !Number.isSafeInteger(amountMinor) ||
    !Number.isInteger(minorUnitScale) ||
    minorUnitScale < 0 ||
    minorUnitScale > 6
  ) {
    return null;
  }

  const majorAmount = amountMinor / 10 ** minorUnitScale;
  const formatted = new Intl.NumberFormat(locale, {
    minimumFractionDigits: minorUnitScale,
    maximumFractionDigits: minorUnitScale,
  }).format(majorAmount);

  if (!symbol) {
    return formatted;
  }

  return symbolPosition === "suffix"
    ? `${formatted} ${symbol}`
    : `${symbol}${formatted}`;
}

export function formatQuantity(
  quantity: number | null,
  unitSymbol: string | null,
  locale: string,
): string | null {
  if (quantity === null || !Number.isFinite(quantity)) {
    return null;
  }

  const formatted = new Intl.NumberFormat(locale, {
    maximumFractionDigits: 3,
  }).format(quantity);

  return unitSymbol ? `${formatted} ${unitSymbol}` : formatted;
}
