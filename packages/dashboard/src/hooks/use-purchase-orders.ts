import type {
  PurchaseOrder,
  PurchaseOrderCreateParams,
  PurchaseOrderUpdateParams,
  ReceivableCloseParams,
  StockReceipt,
  StockReceiptCreateParams,
} from '@spree/admin-sdk'
import {
  adminClient,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import i18n from 'i18next'

/** The lines carry the costs, and the supplier is the document's counterparty. */
const DETAIL_EXPAND = ['items', 'supplier', 'destination_location']

export function usePurchaseOrder(id: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('purchase-orders', id ?? 'noop'),
    queryFn: () => adminClient.purchaseOrders.get(id as string, { expand: DETAIL_EXPAND }),
    enabled: !!id,
  })
}

export function useCreatePurchaseOrder() {
  return useResourceMutation<PurchaseOrder, Error, PurchaseOrderCreateParams>({
    mutationFn: (params) => adminClient.purchaseOrders.create(params),
    invalidate: [['purchase-orders']],
    successMessage: i18n.t('admin.purchase_orders.messages.created'),
    errorMessage: i18n.t('admin.purchase_orders.errors.failed_to_create'),
    // These screens have no inline error surface.
    showValidationErrors: true,
  })
}

export function useUpdatePurchaseOrder(id: string) {
  return useResourceMutation<PurchaseOrder, Error, PurchaseOrderUpdateParams>({
    mutationFn: (params) => adminClient.purchaseOrders.update(id, params),
    invalidate: [['purchase-orders'], ['purchase-orders', id]],
    successMessage: i18n.t('admin.purchase_orders.messages.saved'),
    errorMessage: i18n.t('admin.purchase_orders.errors.failed_to_save'),
    // These screens have no inline error surface.
    showValidationErrors: true,
  })
}

export function useDeletePurchaseOrder() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.purchaseOrders.delete(id),
    invalidate: [['purchase-orders']],
    successMessage: i18n.t('admin.purchase_orders.messages.deleted'),
    errorMessage: i18n.t('admin.purchase_orders.errors.failed_to_delete'),
    // These screens have no inline error surface.
    showValidationErrors: true,
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('purchase-orders', id) })
    },
  })
}

export function useMarkPurchaseOrderOrdered(id: string) {
  return useResourceMutation<PurchaseOrder, Error, void>({
    mutationFn: () => adminClient.purchaseOrders.markOrdered(id),
    invalidate: [['purchase-orders'], ['purchase-orders', id]],
    successMessage: i18n.t('admin.purchase_orders.messages.ordered'),
    errorMessage: i18n.t('admin.purchase_orders.errors.failed_to_order'),
    // These screens have no inline error surface.
    showValidationErrors: true,
  })
}

/** The deliveries booked against an order, with their lines. */
export function usePurchaseOrderReceipts(id: string) {
  return useQuery({
    queryKey: useResourceKey('purchase-orders', id, 'stock-receipts'),
    queryFn: () => adminClient.purchaseOrders.stockReceipts.list(id, { expand: ['items'] }),
  })
}

/** The first moment purchased goods count toward availability. */
export function useCreatePurchaseOrderReceipt(id: string) {
  return useResourceMutation<StockReceipt, Error, StockReceiptCreateParams | undefined>({
    mutationFn: (params) =>
      adminClient.purchaseOrders.stockReceipts.create(id, params ?? undefined),
    invalidate: [
      ['purchase-orders'],
      ['purchase-orders', id],
      ['purchase-orders', id, 'stock-receipts'],
      ['stock-levels'],
      ['stock-movements'],
    ],
    successMessage: i18n.t('admin.purchase_orders.messages.received'),
    errorMessage: i18n.t('admin.purchase_orders.errors.failed_to_receive'),
    // These screens have no inline error surface.
    showValidationErrors: true,
  })
}

/** Ends an order whose balance the supplier will not deliver. */
export function useClosePurchaseOrder(id: string) {
  return useResourceMutation<PurchaseOrder, Error, ReceivableCloseParams | undefined>({
    mutationFn: (params) => adminClient.purchaseOrders.close(id, params ?? undefined),
    invalidate: [['purchase-orders'], ['purchase-orders', id]],
    successMessage: i18n.t('admin.purchase_orders.messages.closed'),
    errorMessage: i18n.t('admin.purchase_orders.errors.failed_to_close'),
    showValidationErrors: true,
  })
}

/** Reopens a placed order for editing, while no delivery has been booked. */
export function useMarkPurchaseOrderDraft(id: string) {
  return useResourceMutation<PurchaseOrder, Error, void>({
    mutationFn: () => adminClient.purchaseOrders.markDraft(id),
    invalidate: [['purchase-orders'], ['purchase-orders', id]],
    successMessage: i18n.t('admin.purchase_orders.messages.marked_draft'),
    errorMessage: i18n.t('admin.purchase_orders.errors.failed_to_mark_draft'),
    showValidationErrors: true,
  })
}

export function useCancelPurchaseOrder(id: string) {
  return useResourceMutation<PurchaseOrder, Error, { reason?: string } | undefined>({
    mutationFn: (params) => adminClient.purchaseOrders.cancel(id, params ?? undefined),
    invalidate: [['purchase-orders'], ['purchase-orders', id]],
    successMessage: i18n.t('admin.purchase_orders.messages.canceled'),
    errorMessage: i18n.t('admin.purchase_orders.errors.failed_to_cancel'),
    // These screens have no inline error surface.
    showValidationErrors: true,
  })
}
