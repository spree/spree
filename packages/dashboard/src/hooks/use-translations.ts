import type {
  Locale,
  ResourceTranslations,
  TranslatableResource,
  TranslationCoverage,
} from '@spree/admin-sdk'
import { adminClient, useResourceKey, useResourceKeyBuilder } from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { useCallback } from 'react'

/** The locales a merchant can translate content into (for nice display names). */
export function useLocales() {
  return useQuery<Locale[]>({
    queryKey: useResourceKey('locales'),
    queryFn: () => adminClient.locales.list(),
  })
}

/**
 * Resolves a locale code to the display name the server reports for it,
 * falling back to the bare code while the locale list is still loading.
 */
export function useLocaleName() {
  const { data: locales } = useLocales()

  return useCallback(
    (code: string) => locales?.find((locale) => locale.code === code)?.name ?? code,
    [locales],
  )
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
  collection: adminClient.collections.translations,
  option_type: adminClient.optionTypes.translations,
} as const

export type TranslatableResourceType = keyof typeof TRANSLATIONS_ACCESSORS

/**
 * Whether the dashboard can open the translation editor for a resource type.
 * The server's registry says which types have a matrix route; this says which
 * of those the SDK actually reaches, so a surface listing types from the
 * registry never offers one whose editor would fail to fetch.
 */
export function isTranslatableResourceType(
  resourceType: string,
): resourceType is TranslatableResourceType {
  // `Object.hasOwn` rather than `in`: the latter walks the prototype chain, so
  // "constructor" or "toString" would pass and then resolve to a non-accessor.
  return Object.hasOwn(TRANSLATIONS_ACCESSORS, resourceType)
}

/**
 * Logical query-key prefix for every translations query — coverage grids and
 * per-record matrices. Product (and other catalog) writes must invalidate
 * this prefix: the matrix used to live under `['product', id, 'translations']`,
 * which `['products']` never matches, so editing a record left the
 * translations page serving a stale cache.
 */
export const TRANSLATIONS_QUERY_RESOURCE = 'translations'

/**
 * Marks every translations query stale and refetches observers — including
 * ones that are not mounted. Prefix invalidation with the default
 * `refetchType: 'active'` only refreshes the open page; a coverage grid
 * visited earlier stayed on the pre-save payload until staleTime elapsed.
 */
export function useInvalidateTranslations() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useCallback(
    () =>
      queryClient.invalidateQueries({
        queryKey: buildKey(TRANSLATIONS_QUERY_RESOURCE),
        refetchType: 'all',
      }),
    [queryClient, buildKey],
  )
}

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
    queryKey: useResourceKey(TRANSLATIONS_QUERY_RESOURCE, resourceType, resourceId),
    queryFn: () => TRANSLATIONS_ACCESSORS[resourceType].get(resourceId),
    enabled: !!resourceId,
    // Source values change when the catalog record is saved. The default
    // 60s staleTime would otherwise keep the editor on the pre-save name
    // after the merchant edits the product and reopens this dialog.
    refetchOnMount: 'always',
  })
}

/**
 * The translatable-resource registry: which resource types exist, what fields
 * each has, and which have a dedicated read route. Drives the centralized
 * page's tabs, so adding a translatable model needs no dashboard change.
 */
export function useTranslatableResources() {
  return useQuery<TranslatableResource[]>({
    queryKey: useResourceKey('translatable_resources'),
    queryFn: () => adminClient.translatableResources.list(),
  })
}

/**
 * Translation coverage across a whole resource type — per-locale totals plus a
 * page of records carrying how many fields each has translated.
 */
export function useTranslationCoverage(
  resourceType: string,
  params: { page?: number; limit?: number } & Record<string, unknown>,
) {
  return useQuery({
    queryKey: useResourceKey(TRANSLATIONS_QUERY_RESOURCE, 'coverage', resourceType, params),
    queryFn: () => adminClient.translations.coverage(resourceType, params),
    enabled: !!resourceType,
    // Hold the previous result while a new term or page loads. Without it
    // every keystroke is a fresh query key with no data, so the page swaps to
    // its loading state and unmounts the search box the merchant is typing in.
    placeholderData: (previous) => previous,
    // Always refetch when the merchant opens this page. Catalog edits and
    // translation saves invalidate the shared prefix, but a missed key still
    // left the 60s cache serving the previous name and coverage badges.
    refetchOnMount: 'always',
  })
}

export type { TranslationCoverage }
