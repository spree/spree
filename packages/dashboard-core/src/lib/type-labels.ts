import i18n from 'i18next'

/**
 * Type catalog families the Admin API exposes. Each entry on the wire carries
 * a stable snake_case `type` code; the `label`/`description` beside it are a
 * fallback for clients without their own translation, not the source of
 * truth. The dashboard renders the code through its own locale files and
 * reaches for the fallback only when it has no key — which is what an
 * extension gem shipping a Ruby type but no dashboard locales gets.
 */
export type TypeFamily =
  | 'promotion_rule'
  | 'promotion_action'
  | 'calculator'
  | 'order_routing_rule'
  | 'collection_rule'
  | 'price_rule'
  | 'commission_rule'
  | 'delivery_method_rule'
  | 'seller_requirement'
  | 'integration'
  | 'permission'

type Facet = 'name' | 'description'

function i18nKey(family: TypeFamily, code: string, facet: Facet): string {
  return `admin.types.${family}.${code}.${facet}`
}

/**
 * Localized name for an API type code.
 *
 * @param family which type catalog the code belongs to
 * @param code the stable snake_case type code (e.g. `item_total`, `flat_rate`)
 * @param fallback the API-provided label, used when no translation exists
 * @returns the localized name, the fallback, or the bare code
 */
export function typeLabel(family: TypeFamily, code: string, fallback?: string | null): string {
  const key = i18nKey(family, code, 'name')
  if (i18n.exists(key)) return i18n.t(key)
  return fallback?.trim() || code
}

/**
 * Localized description for an API type code.
 *
 * Returns an empty string when neither a translation nor a fallback exists —
 * descriptions are optional helper copy, so callers render nothing rather
 * than a bare code.
 *
 * @param family which type catalog the code belongs to
 * @param code the stable snake_case type code
 * @param fallback the API-provided description, used when no translation exists
 * @returns the localized description, the fallback, or an empty string
 */
export function typeDescription(
  family: TypeFamily,
  code: string,
  fallback?: string | null,
): string {
  const key = i18nKey(family, code, 'description')
  if (i18n.exists(key)) return i18n.t(key)
  return fallback?.trim() || ''
}

/**
 * Localized label for a group of permission catalog entries, keyed by the
 * group code the API returns (`catalog`, `orders`, …).
 *
 * @param code the group code
 * @param fallback the API-provided group label
 * @returns the localized group label, the fallback, or the bare code
 */
export function permissionGroupLabel(code: string, fallback?: string | null): string {
  const key = `admin.types.permission_group.${code}.name`
  if (i18n.exists(key)) return i18n.t(key)
  return fallback?.trim() || code
}
