import type { Locale } from '@spree/admin-sdk'
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
 * Full translation matrix for a product: source values + content type per
 * translatable field, plus the translated value for every supported locale.
 * Writes go through the batch endpoint (see ResourceTranslationsDialog).
 */
export function useProductTranslations(productId: string) {
  return useQuery({
    queryKey: useResourceKey('products', productId, 'translations'),
    queryFn: () => adminClient.products.translations.get(productId),
    enabled: !!productId,
  })
}

/**
 * Translation matrix for an option type, with its option values nested under
 * `children` so the editor renders type + values together.
 */
export function useOptionTypeTranslations(optionTypeId: string) {
  return useQuery({
    queryKey: useResourceKey('option-types', optionTypeId, 'translations'),
    queryFn: () => adminClient.optionTypes.translations.get(optionTypeId),
    enabled: !!optionTypeId,
  })
}

/** Full translation matrix for a category. */
export function useCategoryTranslations(categoryId: string) {
  return useQuery({
    queryKey: useResourceKey('categories', categoryId, 'translations'),
    queryFn: () => adminClient.categories.translations.get(categoryId),
    enabled: !!categoryId,
  })
}
