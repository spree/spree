import type { StockTransfer, StockTransferCreateParams } from '@spree/admin-sdk'
import {
  adminClient,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'

export function useStockTransfer(id: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('stock-transfers', id ?? 'noop'),
    queryFn: () =>
      adminClient.stockTransfers.get(id as string, {
        expand: ['source_location', 'destination_location'],
      }),
    enabled: !!id,
  })
}

export function useCreateStockTransfer() {
  return useResourceMutation<StockTransfer, Error, StockTransferCreateParams>({
    mutationFn: (params) => adminClient.stockTransfers.create(params),
    invalidate: [['stock-transfers']],
    successMessage: 'Stock transfer recorded',
    errorMessage: 'Failed to record stock transfer',
  })
}

export function useDeleteStockTransfer() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.stockTransfers.delete(id),
    invalidate: [['stock-transfers']],
    successMessage: 'Stock transfer deleted',
    errorMessage: 'Failed to delete stock transfer',
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('stock-transfers', id) })
    },
  })
}
