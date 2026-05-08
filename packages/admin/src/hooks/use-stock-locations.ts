import type {
  StockLocation,
  StockLocationCreateParams,
  StockLocationUpdateParams,
} from '@spree/admin-sdk'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { adminClient } from '@/client'
import { useResourceMutation } from '@/hooks/use-resource-mutation'

export const stockLocationsQueryKey = ['stock-locations'] as const

export function stockLocationQueryKey(id: string) {
  return ['stock-locations', id] as const
}

interface UseStockLocationsParams {
  page?: number
  limit?: number
}

// API caps `limit` at 100. The page is configurable so callers with more
// than 100 locations can paginate; the typical merchant has a handful.
export function useStockLocations({ page = 1, limit = 100 }: UseStockLocationsParams = {}) {
  return useQuery({
    queryKey: [...stockLocationsQueryKey, { page, limit }],
    queryFn: () => adminClient.stockLocations.list({ page, limit }),
  })
}

export function useStockLocation(id: string | undefined) {
  return useQuery({
    queryKey: id ? stockLocationQueryKey(id) : ['stock-locations', 'noop'],
    queryFn: () => adminClient.stockLocations.get(id as string),
    enabled: !!id,
  })
}

export function useCreateStockLocation() {
  return useResourceMutation<StockLocation, Error, StockLocationCreateParams>({
    mutationFn: (params) => adminClient.stockLocations.create(params),
    invalidate: [stockLocationsQueryKey],
    successMessage: 'Stock location created',
    errorMessage: 'Failed to create stock location',
  })
}

export function useUpdateStockLocation(id: string) {
  return useResourceMutation<StockLocation, Error, StockLocationUpdateParams>({
    mutationFn: (params) => adminClient.stockLocations.update(id, params),
    invalidate: [stockLocationsQueryKey, stockLocationQueryKey(id)],
    successMessage: 'Stock location updated',
    errorMessage: 'Failed to update stock location',
  })
}

export function useDeleteStockLocation() {
  const queryClient = useQueryClient()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.stockLocations.delete(id),
    invalidate: [stockLocationsQueryKey],
    successMessage: 'Stock location deleted',
    errorMessage: 'Failed to delete stock location',
    onSuccess: (_data, id) => {
      // Drop the individual-resource cache so any open detail view stops
      // showing stale data after the row is gone.
      queryClient.removeQueries({ queryKey: stockLocationQueryKey(id) })
    },
  })
}
