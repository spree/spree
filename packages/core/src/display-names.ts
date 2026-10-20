/**
 * The name of a country, currency, language or other code in a reader's
 * language, through `Intl.DisplayNames`, falling back to English. Answers
 * `undefined` when the runtime has no name for it or the code is malformed,
 * so the caller chooses its own fallback (usually the code itself).
 *
 * @example intlDisplayName('region', 'de', 'US') // "Vereinigte Staaten"
 */
export function intlDisplayName(
  type: Intl.DisplayNamesType,
  locale: string,
  code: string,
): string | undefined {
  try {
    return new Intl.DisplayNames([locale, 'en'], { type }).of(code)
  } catch {
    return undefined
  }
}
