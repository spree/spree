import {
  adminClient,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { type QueryKey, useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import i18n from 'i18next'

export function useOrder(orderId: string) {
  return useQuery({
    queryKey: useResourceKey('orders', orderId),
    queryFn: () =>
      adminClient.orders.get(orderId, {
        expand: [
          'items',
          'fulfillments',
          'fulfillments.fulfillment_items',
          'fulfillments.delivery_method',
          'fulfillments.stock_location',
          'fulfillments.delivery_rates',
          'fulfillments.delivery_rates.delivery_method',
          'payments',
          'payments.payment_method',
          'payments.capture_events',
          'payments.refunds',
          // An order from a split checkout has no payments of its own; what
          // it has is a share of each payment made against its group.
          'payment_splits',
          'billing_address',
          'shipping_address',
          'customer',
          'created_by',
          'canceler',
          'approver',
          'market',
          'channel',
        ],
      }),
    enabled: !!orderId,
  })
}

/**
 * Generic factory for an order mutation that invalidates the order detail
 * query on success. Use this for operations that don't fit the toast-bundled
 * `useResourceMutation` (e.g., chained updates, custom error handling).
 */
export function useOrderMutation<TParams>(
  orderId: string,
  mutationFn: (params: TParams) => Promise<unknown>,
) {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()
  return useMutation({
    mutationFn,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: buildKey('orders', orderId) }),
  })
}

/**
 * Bare logical key for an order — pass to `useResourceMutation`'s
 * `invalidate:` and the storeId will be auto-injected at position 1.
 */
export function orderQueryKey(orderId: string): QueryKey {
  return ['orders', orderId]
}

/**
 * Throws a draft order away. Only a draft with no settled payment can go —
 * the backend refuses anything else, and that refusal is toasted since the
 * order page has no inline error surface to carry it.
 */
export function useDeleteOrder() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (orderId) => adminClient.orders.delete(orderId),
    invalidate: [['orders'], ['draft-orders']],
    successMessage: i18n.t('admin.orders.detail.messages.deleted'),
    errorMessage: i18n.t('admin.orders.detail.errors.delete_failed'),
    showValidationErrors: true,
    onSuccess: (_data, orderId) => {
      queryClient.removeQueries({ queryKey: buildKey('orders', orderId) })
    },
  })
}

export function useOrderTaxLines(orderId: string) {
  return useQuery({
    queryKey: useResourceKey('orders', orderId, 'tax_lines'),
    queryFn: () => adminClient.orders.taxLines.list(orderId),
    enabled: !!orderId,
  })
}

export function useOrderDiscounts(orderId: string) {
  return useQuery({
    queryKey: useResourceKey('orders', orderId, 'discounts'),
    queryFn: () => adminClient.orders.discounts.list(orderId),
    enabled: !!orderId,
  })
}

export function useOrderFees(orderId: string) {
  return useQuery({
    queryKey: useResourceKey('orders', orderId, 'fees'),
    queryFn: () => adminClient.orders.fees.list(orderId),
    enabled: !!orderId,
  })
}

/**
 * Keyed under the order, so anything that refreshes the order — saving an
 * edit, receiving a return — refreshes its change history too.
 */
export function useOrderActivities(orderId: string, page: number) {
  return useQuery({
    queryKey: useResourceKey('orders', orderId, 'activities', page),
    queryFn: () =>
      adminClient.orders.activities.list(orderId, {
        page,
        limit: 25,
        expand: ['actor', 'order_change.actions.variant'],
      }),
    enabled: !!orderId,
  })
}

/** The change waiting to be applied, if any — an order has at most one open. */
export function useRequestedOrderChange(orderId: string) {
  return useQuery({
    queryKey: useResourceKey('orders', orderId, 'order_changes', 'requested'),
    queryFn: () =>
      adminClient.orders.orderChanges.list(orderId, {
        status_eq: 'requested',
        limit: 1,
        expand: ['requested_by', 'actions.variant'],
      }),
    select: (response) => response.data[0] ?? null,
    enabled: !!orderId,
  })
}

export function useOrderComment(orderId: string) {
  return useResourceMutation({
    mutationFn: (body: string) => adminClient.orders.activities.create(orderId, { body }),
    invalidate: [orderQueryKey(orderId)],
    successMessage: false,
    showValidationErrors: true,
  })
}

export function useDeleteOrderComment(orderId: string) {
  return useResourceMutation({
    mutationFn: (id: string) => adminClient.orders.activities.delete(orderId, id),
    invalidate: [orderQueryKey(orderId)],
    successMessage: i18n.t('admin.orders.detail.timeline.comment_deleted'),
  })
}

/** Applies or discards the order's requested change. */
export function useSettleOrderChange(orderId: string) {
  return useResourceMutation({
    mutationFn: ({ id, action }: { id: string; action: 'confirm' | 'cancel' }) =>
      action === 'confirm'
        ? adminClient.orders.orderChanges.confirm(orderId, id)
        : adminClient.orders.orderChanges.cancel(orderId, id),
    invalidate: [orderQueryKey(orderId)],
    successMessage: false,
    showValidationErrors: true,
  })
}

/**
 * Ransack predicates go in flat: the SDK wraps them into `q[...]` itself, so a
 * nested `q` becomes `q[q]=[object Object]`, which Ransack ignores — and an
 * unfiltered list is every commission line in the store, rendered against
 * whichever order happens to be open.
 */
export function commissionLinesParams(orderId: string) {
  return {
    order_id_eq: orderId,
    limit: 100,
    expand: ['commission_rate'],
  }
}

async function listAllCommissionLines(orderId: string) {
  const params = commissionLinesParams(orderId)
  const first = await adminClient.commissionLines.list({ ...params, page: 1 })
  const rest = await Promise.all(
    Array.from({ length: (first.meta?.pages ?? 1) - 1 }, (_, index) =>
      adminClient.commissionLines.list({ ...params, page: index + 2 }),
    ),
  )

  return {
    ...first,
    data: [...first.data, ...rest.flatMap((page) => page.data)],
  }
}

export function useOrderCommissionLines(orderId: string, options?: { enabled?: boolean }) {
  return useQuery({
    queryKey: useResourceKey('orders', orderId, 'commission_lines'),
    queryFn: () => listAllCommissionLines(orderId),
    enabled: !!orderId && (options?.enabled ?? true),
  })
}

/**
 * Mutation for typed adjustment rows: invalidates the order detail AND the
 * nested tax_lines/discounts/fees lists (totals change server-side on every
 * row mutation).
 */
export function useOrderAdjustmentLinesMutation<TParams>(
  orderId: string,
  mutationFn: (params: TParams) => Promise<unknown>,
) {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()
  return useMutation({
    mutationFn,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: buildKey('orders', orderId) }),
  })
}
