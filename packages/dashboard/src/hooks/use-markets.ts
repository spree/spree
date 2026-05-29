import type { Market, MarketCreateParams, MarketUpdateParams } from '@spree/admin-sdk'
import { adminClient, useResourceMutation, useStore } from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'

export const marketsQueryKey = ['markets'] as const

export function marketQueryKey(id: string) {
  return ['markets', id] as const
}

interface UseMarketsParams {
  page?: number
  limit?: number
  expand?: string[]
}

export function useMarkets({ page = 1, limit = 100, expand }: UseMarketsParams = {}) {
  return useQuery({
    queryKey: [...marketsQueryKey, { page, limit, expand: expand?.join(',') ?? '' }],
    queryFn: () => adminClient.markets.list({ page, limit, ...(expand ? { expand } : {}) }),
    staleTime: 1000 * 60 * 5,
  })
}

/**
 * Cached full-list fetch for markets — markets are store-scoped, rarely
 * change, and a store typically has only a handful. Reused by pickers
 * (e.g. the Market price rule) that need to filter client-side without
 * round-tripping the API on each keystroke. `storeId` is in the key so
 * switching stores doesn't surface another store's markets.
 */
export function useAllMarkets() {
  const { storeId } = useStore()
  const { data, isLoading } = useQuery({
    queryKey: [...marketsQueryKey, storeId, 'all'],
    queryFn: () => adminClient.markets.list({ limit: 100, sort: 'position' }),
    staleTime: 1000 * 60 * 30,
  })

  return { markets: data?.data ?? [], isLoading }
}

export function useMarket(id: string | undefined) {
  return useQuery({
    queryKey: id ? marketQueryKey(id) : ['markets', 'noop'],
    queryFn: () => adminClient.markets.get(id as string),
    enabled: !!id,
  })
}

export function useCreateMarket() {
  return useResourceMutation<Market, Error, MarketCreateParams>({
    mutationFn: (params) => adminClient.markets.create(params),
    invalidate: [marketsQueryKey],
    successMessage: 'Market created',
    errorMessage: 'Failed to create market',
  })
}

export function useUpdateMarket(id: string) {
  return useResourceMutation<Market, Error, MarketUpdateParams>({
    mutationFn: (params) => adminClient.markets.update(id, params),
    invalidate: [marketsQueryKey, marketQueryKey(id)],
    successMessage: 'Market updated',
    errorMessage: 'Failed to update market',
  })
}

export function useDeleteMarket() {
  const queryClient = useQueryClient()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.markets.delete(id),
    invalidate: [marketsQueryKey],
    successMessage: 'Market deleted',
    errorMessage: 'Failed to delete market',
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: marketQueryKey(id) })
    },
  })
}
