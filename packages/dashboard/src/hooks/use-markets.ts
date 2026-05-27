import type { Market, MarketCreateParams, MarketUpdateParams } from '@spree/admin-sdk'
import { adminClient, useResourceMutation } from '@spree/dashboard-core'
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
