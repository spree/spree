import type { Market, MarketCreateParams, MarketUpdateParams } from '@spree/admin-sdk'
import {
  adminClient,
  listAllMarkets,
  STORE_CONFIG_STALE_TIME,
  STORE_QUERY_RESOURCE,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { type QueryKey, useQuery, useQueryClient } from '@tanstack/react-query'
import i18n from 'i18next'

interface UseMarketsParams {
  page?: number
  limit?: number
  expand?: string[]
}

export function useMarkets({ page = 1, limit = 100, expand }: UseMarketsParams = {}) {
  return useQuery({
    queryKey: useResourceKey('markets', { page, limit, expand: expand?.join(',') ?? '' }),
    queryFn: () => adminClient.markets.list({ page, limit, ...(expand ? { expand } : {}) }),
    staleTime: 1000 * 60 * 5,
  })
}

/**
 * Every market of the store, fetched once and shared with the store shell
 * (which derives the store's currencies and languages from it) and the market
 * list filter. Market writes invalidate it.
 */
export function useAllMarkets({ enabled = true }: { enabled?: boolean } = {}) {
  const { data, isLoading } = useQuery({
    queryKey: useResourceKey('markets', 'all'),
    queryFn: listAllMarkets,
    staleTime: STORE_CONFIG_STALE_TIME,
    enabled,
  })

  return { markets: data?.data ?? [], isLoading }
}

export function useMarket(id: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('markets', id ?? 'noop'),
    queryFn: () => adminClient.markets.get(id as string),
    enabled: !!id,
  })
}

/**
 * Query keys every market write invalidates.
 *
 * `['markets']` covers the shared market list the store shell derives
 * `useStore()`'s currencies and languages from, so pickers drop a removed
 * currency or language at once. `STORE_QUERY_RESOURCE` refreshes the store
 * payload too, which still carries fields the server derives from markets.
 *
 * Exported so the invalidation contract is assertable without rendering hooks.
 */
export const marketWriteInvalidations: QueryKey[] = [['markets'], [STORE_QUERY_RESOURCE]]

/** As above, plus the single-market key the update writes through. */
export function marketUpdateInvalidations(id: string): QueryKey[] {
  return [['markets'], ['markets', id], [STORE_QUERY_RESOURCE]]
}

export function useCreateMarket() {
  return useResourceMutation<Market, Error, MarketCreateParams>({
    mutationFn: (params) => adminClient.markets.create(params),
    invalidate: marketWriteInvalidations,
    successMessage: i18n.t('admin.markets.messages.created'),
    errorMessage: i18n.t('admin.markets.errors.failed_to_create'),
  })
}

export function useUpdateMarket(id: string) {
  return useResourceMutation<Market, Error, MarketUpdateParams>({
    mutationFn: (params) => adminClient.markets.update(id, params),
    invalidate: marketUpdateInvalidations(id),
    successMessage: i18n.t('admin.markets.messages.updated'),
    errorMessage: i18n.t('admin.markets.errors.failed_to_update'),
  })
}

export function useDeleteMarket() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.markets.delete(id),
    invalidate: marketWriteInvalidations,
    successMessage: i18n.t('admin.markets.messages.deleted'),
    errorMessage: i18n.t('admin.markets.errors.failed_to_delete'),
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('markets', id) })
    },
  })
}

/** Market picker for list filters, reading the shared list above. */
export function marketAutocompleteProps() {
  return {
    queryKey: 'markets',
    staleTime: STORE_CONFIG_STALE_TIME,
    search: (q: string) =>
      adminClient.markets.list({ search: q, limit: 100, sort: 'position', fields: ['name'] }),
    hydrate: (ids: string[]) => adminClient.markets.list({ id_in: ids, limit: ids.length }),
    listAll: listAllMarkets,
    getOptionLabel: (market: Market) => market.name ?? market.id,
    placeholder: i18n.t('admin.markets.search_placeholder'),
    emptyText: i18n.t('admin.markets.empty'),
  }
}
