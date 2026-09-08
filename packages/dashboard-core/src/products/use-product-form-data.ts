import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import type {
  PanelCollection,
  PanelDeliveryProfile,
  PanelMarket,
  PanelNamedRecord,
  PanelOptionType,
  PanelPackageType,
  PanelProductType,
} from '../api-client'
import { getApiClient } from '../api-client'
import { useResourceKey } from '../lib/query-keys'

/**
 * The reference data the product form's pickers read.
 *
 * Deliberately separate from the operator dashboard's own `useOptionTypes`
 * and friends, which back its management pages and carry the full CRUD each
 * resource needs. These read through the registered panel client, so the same
 * cards work in a seller's panel against the Seller API — and answer empty
 * when a panel registers no such resource, which is how a card knows to hide.
 *
 * Keys go through `useResourceKey`, so they carry the tenant — the store on the
 * operator's panel, the seller on a seller's. Flat keys would serve one
 * tenant's categories to the next within the stale window, and a save from that
 * form would write ids belonging to somebody else.
 *
 * They are also keyed UNDER the resource they mirror — `['package-types',
 * tenant, 'panel-form', ...]`, not `['panel-form-package-types', tenant]` — so
 * that the `invalidate: [['package-types']]` a management page already declares
 * sweeps them by prefix. Keyed to one side, a carton created in settings stayed
 * invisible to this form for the whole stale window below, and the section that
 * only renders once a carton exists went on claiming there were none.
 */

const FIVE_MINUTES = 1000 * 60 * 5

export function useFormOptionTypes(enabled = true) {
  const client = getApiClient()

  return useQuery({
    queryKey: useResourceKey('option-types', 'panel-form'),
    queryFn: async (): Promise<{ data: PanelOptionType[] }> =>
      (await client.optionTypes?.list({ limit: 100 })) ?? { data: [] },
    enabled: enabled && Boolean(client.optionTypes),
    staleTime: FIVE_MINUTES,
  })
}

export function useFormCategories(enabled = true) {
  const client = getApiClient()

  return useQuery({
    queryKey: useResourceKey('categories', 'panel-form'),
    queryFn: async (): Promise<{ data: PanelNamedRecord[] }> =>
      (await client.categories?.list({ limit: 100 })) ?? { data: [] },
    enabled: enabled && Boolean(client.categories),
    staleTime: FIVE_MINUTES,
  })
}

export function useFormCollections(enabled = true) {
  const client = getApiClient()

  return useQuery({
    queryKey: useResourceKey('collections', 'panel-form'),
    queryFn: async (): Promise<{ data: PanelCollection[] }> =>
      (await client.collections?.list({ limit: 100 })) ?? { data: [] },
    enabled: enabled && Boolean(client.collections),
    staleTime: FIVE_MINUTES,
  })
}

export function useFormProductTypes(enabled = true) {
  const client = getApiClient()

  return useQuery({
    queryKey: useResourceKey('product-types', 'panel-form'),
    queryFn: async (): Promise<{ data: PanelProductType[] }> =>
      (await client.productTypes?.list({ limit: 100 })) ?? { data: [] },
    enabled: enabled && Boolean(client.productTypes),
    staleTime: FIVE_MINUTES,
  })
}

/** One product type, for the option types and custom fields it seeds. */
export function useFormProductType(id?: string) {
  const client = getApiClient()

  return useQuery({
    queryKey: useResourceKey('product-types', 'panel-form', id),
    queryFn: () => client.productTypes?.get(id as string) as Promise<PanelProductType>,
    enabled: Boolean(id) && Boolean(client.productTypes),
    staleTime: FIVE_MINUTES,
  })
}

/**
 * Option types named by a product type, resolved from the full list rather
 * than fetched by id — the list is already cached and small enough that a
 * second round trip buys nothing.
 */
export function useFormOptionTypesByIds(ids?: string[]) {
  const { data, ...rest } = useFormOptionTypes(Boolean(ids?.length))
  const wanted = new Set(ids ?? [])

  return {
    ...rest,
    data: ids?.length
      ? { data: (data?.data ?? []).filter((type) => wanted.has(type.id)) }
      : undefined,
  }
}

export function useFormTaxCategories() {
  const client = getApiClient()

  return useQuery({
    queryKey: useResourceKey('tax-categories', 'panel-form'),
    queryFn: async (): Promise<{ data: PanelNamedRecord[] }> =>
      (await client.taxCategories?.list({ limit: 100 })) ?? { data: [] },
    enabled: Boolean(client.taxCategories),
    staleTime: FIVE_MINUTES,
  })
}

export function useFormDeliveryProfiles() {
  const client = getApiClient()

  return useQuery({
    queryKey: useResourceKey('delivery-profiles', 'panel-form'),
    queryFn: async (): Promise<{ data: PanelDeliveryProfile[] }> =>
      (await client.deliveryProfiles?.list({ limit: 100 })) ?? { data: [] },
    enabled: Boolean(client.deliveryProfiles),
    staleTime: FIVE_MINUTES,
  })
}

/**
 * Carton package types, plus whether this panel manages them at all.
 *
 * `supported` is what separates "this panel has no such page" (a seller's,
 * where the packing card should not appear) from "the store has not created a
 * carton yet" (an operator's, where it appears disabled and says where to go).
 */
export function useFormCartonPackageTypes() {
  const client = getApiClient()
  const supported = Boolean(client.packageTypes)

  const query = useQuery({
    queryKey: useResourceKey('package-types', 'panel-form', 'cartons'),
    queryFn: async (): Promise<{ data: PanelPackageType[] }> =>
      (await client.packageTypes?.list({ limit: 100, kind_eq: 'carton' })) ?? { data: [] },
    enabled: supported,
    staleTime: FIVE_MINUTES,
  })

  return { ...query, supported }
}

/**
 * Removing a file already on the product. A panel whose client registers no
 * deletion answers a no-op mutation, so the gallery still drops the row from
 * the form and the save reconciles it.
 */
export function useFormDeleteProductMedia(productId: string) {
  const client = getApiClient()
  const queryClient = useQueryClient()
  // Resolved here rather than in the callback: it is a hook. No `panel-form`
  // segment on this one — it must match the key the gallery reads, which is
  // the operator dashboard's own `useProductMedia`.
  const mediaKey = useResourceKey('products', productId, 'media')

  return useMutation({
    mutationFn: async (mediaId: string) => {
      await client.deleteProductMedia?.(productId, mediaId)
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: mediaKey })
    },
  })
}

export function useCreateOptionType() {
  const client = getApiClient()
  const queryClient = useQueryClient()
  const optionTypesKey = useResourceKey('option-types', 'panel-form')

  return useMutation({
    mutationFn: (params: { name: string; label: string } & Record<string, unknown>) =>
      client.optionTypes?.create?.(params) as Promise<PanelOptionType>,
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: optionTypesKey })
    },
  })
}

export function useUpdateOptionType(id: string) {
  const client = getApiClient()
  const queryClient = useQueryClient()
  const optionTypesKey = useResourceKey('option-types', 'panel-form')

  return useMutation({
    mutationFn: (
      params: { option_values?: Array<{ name: string; label: string }> } & Record<string, unknown>,
    ) => client.optionTypes?.update?.(id, params) as Promise<PanelOptionType>,
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: optionTypesKey })
    },
  })
}

/**
 * Props for the shared multi-select pickers, reading through the registered
 * client so the same card works in either panel.
 */
export function categoryAutocompleteProps(queryKey: string) {
  const client = getApiClient()

  return {
    queryKey,
    search: async (query: string) =>
      (await client.categories?.list({ name_cont: query, limit: 20 })) ?? { data: [] },
    hydrate: async (ids: string[]) =>
      (await client.categories?.list({ id_in: ids, limit: ids.length })) ?? { data: [] },
    getOptionLabel: (category: PanelNamedRecord & { pretty_name?: string }) =>
      category.pretty_name ?? category.name ?? category.id,
  }
}

export function collectionAutocompleteProps(queryKey: string) {
  const client = getApiClient()

  return {
    queryKey,
    search: async (query: string) =>
      (await client.collections?.list({ name_cont: query, limit: 20 })) ?? { data: [] },
    hydrate: async (ids: string[]) =>
      (await client.collections?.list({ id_in: ids, limit: ids.length })) ?? { data: [] },
    getOptionLabel: (collection: PanelCollection) => collection.name ?? collection.id,
  }
}

/**
 * Resolves a currency to the locale its amounts are typed and shown in, so a
 * EUR field accepts `1.234,56` and normalizes it to `1234.56`. Mirrors the
 * operator dashboard's `useCurrencyLocale`, reading through the registered
 * client so the shared price editor works in either panel; a panel with no
 * markets answers undefined and callers fall back to the UI language.
 */
export function useFormCurrencyLocale(): (currency: string | undefined) => string | undefined {
  const client = getApiClient()

  const { data } = useQuery({
    queryKey: useResourceKey('markets', 'panel-form'),
    queryFn: async (): Promise<{ data: PanelMarket[] }> =>
      (await client.markets?.list({ limit: 100 })) ?? { data: [] },
    enabled: Boolean(client.markets),
    staleTime: FIVE_MINUTES,
  })

  const markets = data?.data ?? []

  return (currency) => {
    if (!currency) return undefined

    return markets.find((market) => market.currency === currency)?.default_locale ?? undefined
  }
}
