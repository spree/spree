import type { Market, MarketCreateParams, MarketUpdateParams } from '@spree/admin-sdk'
import {
  adminClient,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'
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
 * Cached full-list fetch for markets — markets are store-scoped, rarely
 * change, and a store typically has only a handful. Reused by pickers
 * (e.g. the Market price rule) that need to filter client-side without
 * round-tripping the API on each keystroke.
 */
export function useAllMarkets() {
  const { data, isLoading } = useQuery({
    queryKey: useResourceKey('markets', 'all'),
    queryFn: () => adminClient.markets.list({ limit: 100, sort: 'position' }),
    staleTime: 1000 * 60 * 30,
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

export function useCreateMarket() {
  return useResourceMutation<Market, Error, MarketCreateParams>({
    mutationFn: (params) => adminClient.markets.create(params),
    invalidate: [['markets']],
    successMessage: i18n.t('admin.markets.messages.created'),
    errorMessage: i18n.t('admin.markets.errors.failed_to_create'),
  })
}

export function useUpdateMarket(id: string) {
  return useResourceMutation<Market, Error, MarketUpdateParams>({
    mutationFn: (params) => adminClient.markets.update(id, params),
    invalidate: [['markets'], ['markets', id]],
    successMessage: i18n.t('admin.markets.messages.updated'),
    errorMessage: i18n.t('admin.markets.errors.failed_to_update'),
  })
}

export function useDeleteMarket() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.markets.delete(id),
    invalidate: [['markets']],
    successMessage: i18n.t('admin.markets.messages.deleted'),
    errorMessage: i18n.t('admin.markets.errors.failed_to_delete'),
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('markets', id) })
    },
  })
}
