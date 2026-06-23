import type { StockTransfer, StockTransferCreateParams } from '@spree/admin-sdk'
import {
  adminClient,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import i18n from 'i18next'

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
    successMessage: i18n.t('admin.stock_transfers.messages.recorded'),
    errorMessage: i18n.t('admin.stock_transfers.errors.failed_to_record'),
  })
}

export function useDeleteStockTransfer() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.stockTransfers.delete(id),
    invalidate: [['stock-transfers']],
    successMessage: i18n.t('admin.stock_transfers.messages.deleted'),
    errorMessage: i18n.t('admin.stock_transfers.errors.failed_to_delete'),
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('stock-transfers', id) })
    },
  })
}
