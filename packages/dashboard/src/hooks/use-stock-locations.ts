import type {
  StockLocation,
  StockLocationCreateParams,
  StockLocationUpdateParams,
} from '@spree/admin-sdk'
import {
  adminClient,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'

interface UseStockLocationsParams {
  page?: number
  limit?: number
}

// API caps `limit` at 100. The page is configurable so callers with more
// than 100 locations can paginate; the typical merchant has a handful.
export function useStockLocations({ page = 1, limit = 100 }: UseStockLocationsParams = {}) {
  return useQuery({
    queryKey: useResourceKey('stock-locations', { page, limit }),
    queryFn: () => adminClient.stockLocations.list({ page, limit }),
  })
}

export function useStockLocation(id: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('stock-locations', id ?? 'noop'),
    queryFn: () => adminClient.stockLocations.get(id as string),
    enabled: !!id,
  })
}

export function useCreateStockLocation() {
  return useResourceMutation<StockLocation, Error, StockLocationCreateParams>({
    mutationFn: (params) => adminClient.stockLocations.create(params),
    invalidate: [['stock-locations']],
    successMessage: 'Stock location created',
    errorMessage: 'Failed to create stock location',
  })
}

export function useUpdateStockLocation(id: string) {
  return useResourceMutation<StockLocation, Error, StockLocationUpdateParams>({
    mutationFn: (params) => adminClient.stockLocations.update(id, params),
    invalidate: [['stock-locations'], ['stock-locations', id]],
    successMessage: 'Stock location updated',
    errorMessage: 'Failed to update stock location',
  })
}

export function useDeleteStockLocation() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.stockLocations.delete(id),
    invalidate: [['stock-locations']],
    successMessage: 'Stock location deleted',
    errorMessage: 'Failed to delete stock location',
    onSuccess: (_data, id) => {
      // Drop the individual-resource cache so any open detail view stops
      // showing stale data after the row is gone.
      queryClient.removeQueries({ queryKey: buildKey('stock-locations', id) })
    },
  })
}
