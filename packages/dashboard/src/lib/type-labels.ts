import i18n from 'i18next'

/**
 * Type catalog families returned by the Admin API. Each carries a stable
 * snake_case `type` code plus an English `label`/`description`. We resolve
 * an i18n key from the code so the admin UI can localize the label, falling
 * back to the API's English string for custom/extension types that ship no
 * translation.
 */
export type TypeFamily = 'rule_types' | 'action_types' | 'calculators' | 'order_routing_rule_types'

function i18nKey(family: TypeFamily, code: string, facet: 'name' | 'description'): string {
  // Calculators expose a single flat string (no separate description), so
  // their key is `admin.calculators.<code>`. Rule/action types nest
  // `name` and `description` under their code.
  if (family === 'calculators') return `admin.calculators.${code}`
  if (family === 'order_routing_rule_types')
    return `admin.order_routing_rules.types.${code}.${facet}`
  return `admin.promotions.${family}.${code}.${facet}`
}

/**
 * Localized label for an API type code, falling back to the API-provided
 * `label` when no translation key exists (custom/extension types).
 *
 * @param family which type catalog the code belongs to
 * @param code the stable snake_case type code (e.g. `country`, `flat_percent_item_total`)
 * @param fallback the API's English `label`
 * @returns the localized label, or `fallback`
 */
export function typeLabel(family: TypeFamily, code: string, fallback: string): string {
  const key = i18nKey(family, code, 'name')
  return i18n.exists(key) ? i18n.t(key) : fallback
}

/**
 * Localized description for a rule/action type code, falling back to the
 * API-provided `description`. Calculators have no description key.
 *
 * @param family which type catalog the code belongs to
 * @param code the stable snake_case type code
 * @param fallback the API's English `description`
 * @returns the localized description, or `fallback`
 */
export function typeDescription(family: TypeFamily, code: string, fallback: string): string {
  // Calculators have only a flat name key (no description), so resolving a
  // description key would wrongly return the name — always use the fallback.
  if (family === 'calculators') return fallback
  const key = i18nKey(family, code, 'description')
  return i18n.exists(key) ? i18n.t(key) : fallback
}

/**
 * Localized label for a calculator/rule/action preference field, keyed by
 * the field's `key` under `admin.preferences.<key>`. Falls back to the
 * caller's current label (typically the API label or a humanized key).
 *
 * @param key the preference field key (e.g. `amount`, `flat_percent`)
 * @param fallback the current label to use when no translation exists
 * @returns the localized label, or `fallback`
 */
export function preferenceLabel(key: string, fallback: string): string {
  const i18nKey = `admin.preferences.${key}`
  return i18n.exists(i18nKey) ? i18n.t(i18nKey) : fallback
}
