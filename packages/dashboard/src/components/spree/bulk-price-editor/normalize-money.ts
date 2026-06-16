// Normalize a merchant's locale-formatted money input into the canonical
// decimal string the Admin API expects (`"1234.56"` — period decimal, no
// grouping). Industry-standard: localization is a presentation concern, so the
// dashboard converts here, in the browser, and never relies on the server to
// parse comma-vs-period. See docs/plans/5.5-client-side-money-normalization.md.
//
// The locale is the currency's display locale (its market locale, e.g. EUR →
// `de`), so the same locale drives both display formatting and this parse.

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
  // Remove the locale's grouping separator (explicit char) plus any whitespace
  // (covers narrow/no-break spaces used by some locales as the group char).
  if (group) out = out.split(group).join('')
  out = out.replace(/\s/g, '')
  // Standardize the decimal separator to `.`. Only replace the *last* one in
  // case the locale's decimal char also appeared elsewhere after grouping
  // stripping (defensive — normally there's just one).
  if (decimal !== '.') out = out.split(decimal).join('.')
  // Drop anything that isn't a digit, dot, or leading minus.
  out = out.replace(/[^0-9.-]/g, '')

  return out
}
