import type {
  StockLocation,
  StockLocationCreateParams,
  StockLocationUpdateParams,
} from '@spree/admin-sdk'
import { useQuery } from '@tanstack/react-query'
import { adminClient } from '@/client'
import { useResourceMutation } from '@/hooks/use-resource-mutation'

export const stockLocationsQueryKey = ['stock-locations'] as const

export function stockLocationQueryKey(id: string) {
  return ['stock-locations', id] as const
}

export function useStockLocations() {
  return useQuery({
    queryKey: stockLocationsQueryKey,
    queryFn: () => adminClient.stockLocations.list({ limit: 100 }),
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
  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.stockLocations.delete(id),
    invalidate: [stockLocationsQueryKey],
    successMessage: 'Stock location deleted',
    errorMessage: 'Failed to delete stock location',
  })
}
