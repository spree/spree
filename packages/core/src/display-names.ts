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

/**
 * A language's name in that language itself (`Deutsch`, `Français`, `中文`),
 * for a language picker every reader can find their own language in. Some
 * languages write their names in lowercase, so the first letter is
 * capitalized by that language's own rules. An unknown code answers itself.
 *
 * @example localeEndonym('fr') // "Français"
 */
export function localeEndonym(code: string): string {
  const name = intlDisplayName('language', code, code)
  if (!name) return code

  return name.charAt(0).toLocaleUpperCase(code) + name.slice(1)
}
