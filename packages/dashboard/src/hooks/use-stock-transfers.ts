import type {
  StockTransfer,
  StockTransferCancelParams,
  StockTransferCreateParams,
  StockTransferReceiveParams,
  StockTransferUpdateParams,
} from '@spree/admin-sdk'
import {
  adminClient,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import i18n from 'i18next'

/** The lines and both warehouses: a transfer is unreadable without them. */
const DETAIL_EXPAND = ['items', 'source_location', 'destination_location']

export function useStockTransfer(id: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('stock-transfers', id ?? 'noop'),
    queryFn: () => adminClient.stockTransfers.get(id as string, { expand: DETAIL_EXPAND }),
    enabled: !!id,
  })
}

export function useCreateStockTransfer() {
  return useResourceMutation<StockTransfer, Error, StockTransferCreateParams>({
    mutationFn: (params) => adminClient.stockTransfers.create(params),
    invalidate: [['stock-transfers']],
    successMessage: i18n.t('admin.stock_transfers.messages.created'),
    errorMessage: i18n.t('admin.stock_transfers.errors.failed_to_create'),
    // These screens have no inline error surface.
    showValidationErrors: true,
  })
}

export function useUpdateStockTransfer(id: string) {
  return useResourceMutation<StockTransfer, Error, StockTransferUpdateParams>({
    mutationFn: (params) => adminClient.stockTransfers.update(id, params),
    invalidate: [['stock-transfers'], ['stock-transfers', id]],
    successMessage: i18n.t('admin.stock_transfers.messages.saved'),
    errorMessage: i18n.t('admin.stock_transfers.errors.failed_to_save'),
    // These screens have no inline error surface.
    showValidationErrors: true,
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
    // These screens have no inline error surface.
    showValidationErrors: true,
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('stock-transfers', id) })
    },
  })
}

export function useMarkStockTransferReady(id: string) {
  return useResourceMutation<StockTransfer, Error, void>({
    mutationFn: () => adminClient.stockTransfers.markReady(id),
    invalidate: [['stock-transfers'], ['stock-transfers', id]],
    successMessage: i18n.t('admin.stock_transfers.messages.marked_ready'),
    errorMessage: i18n.t('admin.stock_transfers.errors.failed_to_mark_ready'),
    // These screens have no inline error surface.
    showValidationErrors: true,
  })
}

/**
 * Stock leaves the source warehouse here, so the stock queries a merchant may
 * be looking at go stale too.
 */
export function useMarkStockTransferInTransit(id: string) {
  return useResourceMutation<StockTransfer, Error, { force?: boolean } | undefined>({
    mutationFn: (params) => adminClient.stockTransfers.markInTransit(id, params ?? undefined),
    invalidate: [
      ['stock-transfers'],
      ['stock-transfers', id],
      ['stock-levels'],
      ['stock-movements'],
    ],
    successMessage: i18n.t('admin.stock_transfers.messages.marked_in_transit'),
    errorMessage: i18n.t('admin.stock_transfers.errors.failed_to_mark_in_transit'),
    // These screens have no inline error surface.
    showValidationErrors: true,
  })
}

export function useReceiveStockTransfer(id: string) {
  return useResourceMutation<StockTransfer, Error, StockTransferReceiveParams | undefined>({
    mutationFn: (params) => adminClient.stockTransfers.receive(id, params ?? undefined),
    invalidate: [
      ['stock-transfers'],
      ['stock-transfers', id],
      ['stock-levels'],
      ['stock-movements'],
    ],
    successMessage: i18n.t('admin.stock_transfers.messages.received'),
    errorMessage: i18n.t('admin.stock_transfers.errors.failed_to_receive'),
    // These screens have no inline error surface.
    showValidationErrors: true,
  })
}

export function useCancelStockTransfer(id: string) {
  return useResourceMutation<StockTransfer, Error, StockTransferCancelParams | undefined>({
    mutationFn: (params) => adminClient.stockTransfers.cancel(id, params ?? undefined),
    invalidate: [
      ['stock-transfers'],
      ['stock-transfers', id],
      ['stock-levels'],
      ['stock-movements'],
    ],
    successMessage: i18n.t('admin.stock_transfers.messages.canceled'),
    errorMessage: i18n.t('admin.stock_transfers.errors.failed_to_cancel'),
    // These screens have no inline error surface.
    showValidationErrors: true,
  })
}
