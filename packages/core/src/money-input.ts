// Reading amounts people type. Spree accepts amounts only as canonical decimal
// strings ("1234.56": a period decimal, no grouping), and never parses a
// comma or a period on the server, because how a number is written is a
// presentation concern. A client converts what was typed in the reader's own
// format, in the same locale the field is displayed in, so a value reads back
// exactly as it was shown.

/**
 * Derives a locale's decimal and group separators via `Intl`. `fr` groups with
 * a narrow no-break space (U+202F), so we read the real characters rather than
 * assuming `,`/`.`/`" "`.
 */
function separatorsFor(locale: string): { decimal: string; group: string } {
  try {
    const parts = new Intl.NumberFormat(locale, { useGrouping: true }).formatToParts(11111.1)
    return {
      decimal: parts.find((p) => p.type === 'decimal')?.value ?? '.',
      group: parts.find((p) => p.type === 'group')?.value ?? '',
    }
  } catch {
    return { decimal: '.', group: '' }
  }
}

/**
 * Converts a locale-formatted amount string to a canonical decimal string.
 *
 * - `"1.234,56"` under `de` → `"1234.56"`
 * - `"1 234,56"` under `fr` → `"1234.56"` (narrow-space grouping)
 * - `"19.99"` under `en` → `"19.99"`
 * - `"19.50"` under `de` → `"19.50"` (a period can't be grouping before two digits)
 * - `""` / whitespace → `""`
 *
 * Strips the locale's group separator and any whitespace, standardizes the
 * decimal separator to `.`, and drops stray characters. Keeps the value as a
 * string throughout — never `Number()`-coerces — to preserve precision.
 *
 * @param raw the merchant's typed value
 * @param locale the display locale the value was entered in (e.g. `de`)
 * @returns canonical `"1234.56"`-form string, or `''` for blank input
 */
export function normalizeMoneyInput(raw: string | null | undefined, locale: string): string {
  if (raw == null) return ''
  const trimmed = raw.trim()
  if (trimmed === '') return ''

  const { decimal, group } = separatorsFor(locale)

  let out = trimmed
  // A group separator is always followed by exactly three digits, so a lone
  // one that is not (`19.50` under `de`) is the merchant typing the other
  // decimal mark. `1.500` stays ambiguous and is read the locale's way.
  const groupParts = group.trim() === '' ? [] : out.split(group)
  if (
    groupParts.length === 2 &&
    !out.includes(decimal) &&
    groupParts[1].replace(/\D/g, '').length !== 3
  ) {
    out = groupParts.join(decimal)
  }
  // Remove the locale's grouping separator (explicit char) plus any whitespace
  // (covers narrow/no-break spaces used by some locales as the group char).
  if (group) out = out.split(group).join('')
  out = out.replace(/\s/g, '')
  // Standardize the decimal separator to `.`.
  if (decimal !== '.') out = out.split(decimal).join('.')
  // Drop anything that isn't a digit, dot, or minus.
  out = out.replace(/[^0-9.-]/g, '')

  // Enforce the canonical shape: a single optional leading minus, then digits
  // with at most one decimal point. Stray separators (`1.2.3`) or interior
  // minus signs (`12-3.4`) would otherwise reach the API as malformed values.
  const negative = out.startsWith('-')
  const digitsAndDots = out.replace(/-/g, '')
  const firstDot = digitsAndDots.indexOf('.')
  const canonical =
    firstDot === -1
      ? digitsAndDots
      : `${digitsAndDots.slice(0, firstDot)}.${digitsAndDots.slice(firstDot + 1).replace(/\./g, '')}`

  if (canonical === '' || canonical === '.') return ''
  return negative ? `-${canonical}` : canonical
}

/**
 * A currency's symbol and decimal separator in a locale, for labelling an
 * amount input ("€" and "," for EUR in `de`). An unknown currency falls back
 * to its code and a period.
 */
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
