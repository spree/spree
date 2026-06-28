import type { Locale, ResourceTranslations } from '@spree/admin-sdk'
import { adminClient, useResourceKey } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'

/** The locales a merchant can translate content into (for nice display names). */
export function useLocales() {
  return useQuery<Locale[]>({
    queryKey: useResourceKey('locales'),
    queryFn: () => adminClient.locales.list(),
  })
}

/**
 * Public resource token → SDK translations accessor. The token is the
 * `resource_type` the API uses in translation payloads (e.g. `category` for any
 * Spree::Taxon — see Spree::Translations.public_resource_type). Mirrors the
 * SDK's generic `customFields()` owner-path dispatch. A new translatable
 * resource is one line here — no new hook or adapter component.
 */
const TRANSLATIONS_ACCESSORS = {
  product: adminClient.products.translations,
  category: adminClient.categories.translations,
  option_type: adminClient.optionTypes.translations,
} as const

export type TranslatableResourceType = keyof typeof TRANSLATIONS_ACCESSORS

/**
 * Full translation matrix for any translatable resource: source values +
 * content type per field, plus the translated value for every supported locale
 * (with nested translatable children, e.g. an option type's values). Writes go
 * through the batch endpoint (see ResourceTranslationsDialog).
 */
export function useResourceTranslations(
  resourceType: TranslatableResourceType,
  resourceId: string,
) {
  return useQuery<ResourceTranslations>({
    queryKey: useResourceKey(resourceType, resourceId, 'translations'),
    queryFn: () => TRANSLATIONS_ACCESSORS[resourceType].get(resourceId),
    enabled: !!resourceId,
  })
}
