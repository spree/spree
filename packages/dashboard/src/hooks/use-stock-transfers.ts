import type { StockTransfer, StockTransferCreateParams } from '@spree/admin-sdk'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { adminClient } from '@/client'
import { useResourceMutation } from '@/hooks/use-resource-mutation'

export const stockTransfersQueryKey = ['stock-transfers'] as const

export function stockTransferQueryKey(id: string) {
  return ['stock-transfers', id] as const
}

export function useStockTransfer(id: string | undefined) {
  return useQuery({
    queryKey: id ? stockTransferQueryKey(id) : ['stock-transfers', 'noop'],
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
    invalidate: [stockTransfersQueryKey],
    successMessage: 'Stock transfer recorded',
    errorMessage: 'Failed to record stock transfer',
  })
}

export function useDeleteStockTransfer() {
  const queryClient = useQueryClient()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.stockTransfers.delete(id),
    invalidate: [stockTransfersQueryKey],
    successMessage: 'Stock transfer deleted',
    errorMessage: 'Failed to delete stock transfer',
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: stockTransferQueryKey(id) })
    },
  })
}
