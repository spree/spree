import i18n from 'i18next'

/**
 * Label for a server-supplied enum value: its translation when one exists,
 * otherwise the value humanized.
 *
 * The fallback matters because these lists are open — a status or a kind an
 * extension registers reaches the table before any locale file knows its
 * name, and showing `partially_redeemed` reads better than showing nothing.
 *
 * @param prefix translation key prefix, without the trailing dot
 * @param value the raw value from the API
 */
export function translatedLabel(prefix: string, value: string): string {
  const key = `${prefix}.${value}`
  if (i18n.exists(key)) return i18n.t(key)

  return value.replace(/_/g, ' ').replace(/\b\w/g, (character) => character.toUpperCase())
}
