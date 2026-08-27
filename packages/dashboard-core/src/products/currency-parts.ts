// Resolve a currency code into its symbol + decimal separator under the
// current locale, with a safe fallback for unknown/invalid currencies.
// Shared between the server-backed BulkPriceEditor and the form-backed
// ProductBulkPriceEditor.
export function currencyParts(
  currencyCode: string,
  locale: string,
): { symbol: string; decimal: string } {
  try {
    const parts = new Intl.NumberFormat(locale, {
      style: 'currency',
      currency: currencyCode,
    }).formatToParts(1234.56)
    return {
      symbol: parts.find((p) => p.type === 'currency')?.value ?? currencyCode,
      decimal: parts.find((p) => p.type === 'decimal')?.value ?? '.',
    }
  } catch {
    return { symbol: currencyCode, decimal: '.' }
  }
}
