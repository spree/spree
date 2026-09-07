import type {
  PurchaseOrder,
  PurchaseOrderCreateParams,
  PurchaseOrderReceiveParams,
  PurchaseOrderUpdateParams,
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
  })
}

export function useUpdatePurchaseOrder(id: string) {
  return useResourceMutation<PurchaseOrder, Error, PurchaseOrderUpdateParams>({
    mutationFn: (params) => adminClient.purchaseOrders.update(id, params),
    invalidate: [['purchase-orders'], ['purchase-orders', id]],
    successMessage: i18n.t('admin.purchase_orders.messages.saved'),
    errorMessage: i18n.t('admin.purchase_orders.errors.failed_to_save'),
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
  })
}

/** The first moment purchased goods count toward availability. */
export function useReceivePurchaseOrder(id: string) {
  return useResourceMutation<PurchaseOrder, Error, PurchaseOrderReceiveParams | undefined>({
    mutationFn: (params) => adminClient.purchaseOrders.receive(id, params ?? undefined),
    invalidate: [
      ['purchase-orders'],
      ['purchase-orders', id],
      ['stock-levels'],
      ['stock-movements'],
    ],
    successMessage: i18n.t('admin.purchase_orders.messages.received'),
    errorMessage: i18n.t('admin.purchase_orders.errors.failed_to_receive'),
  })
}

export function useCancelPurchaseOrder(id: string) {
  return useResourceMutation<PurchaseOrder, Error, { reason?: string } | undefined>({
    mutationFn: (params) => adminClient.purchaseOrders.cancel(id, params ?? undefined),
    invalidate: [['purchase-orders'], ['purchase-orders', id]],
    successMessage: i18n.t('admin.purchase_orders.messages.canceled'),
    errorMessage: i18n.t('admin.purchase_orders.errors.failed_to_cancel'),
  })
}
