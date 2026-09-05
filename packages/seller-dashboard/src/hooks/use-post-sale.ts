import { useResourceKey, useResourceKeyBuilder } from '@spree/dashboard-core'
import { toastManager } from '@spree/dashboard-ui'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { sellerClient } from '../api-client'

/**
 * What has come back, or gone wrong, on one order.
 *
 * Fetched separately from the order so its payload stays lean — most orders
 * have none of these.
 */
export function useOrderReturns(orderId: string) {
  return useQuery({
    queryKey: useResourceKey('seller-order-returns', orderId),
    queryFn: () => sellerClient().orders.returns.list(orderId),
    enabled: !!orderId,
  })
}

export function useOrderExchanges(orderId: string) {
  return useQuery({
    queryKey: useResourceKey('seller-order-exchanges', orderId),
    queryFn: () => sellerClient().orders.exchanges.list(orderId),
    enabled: !!orderId,
  })
}

export function useOrderClaims(orderId: string) {
  return useQuery({
    queryKey: useResourceKey('seller-order-claims', orderId),
    queryFn: () => sellerClient().orders.claims.list(orderId),
    enabled: !!orderId,
  })
}

/**
 * Refreshes the list this write belongs to and the order itself — refunding
 * changes what the order is owed.
 */
function usePostSaleMutation<TParams>(
  orderId: string,
  resourceKey: string,
  mutationFn: (params: TParams) => Promise<unknown>,
) {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useMutation({
    mutationFn,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: buildKey(resourceKey, orderId) })
      queryClient.invalidateQueries({ queryKey: buildKey('seller-order', orderId) })
    },
    onError: (error) => {
      toastManager.add({
        type: 'error',
        title: error instanceof Error ? error.message : String(error),
      })
    },
  })
}

export function useReturnActions(orderId: string) {
  const key = 'seller-order-returns'
  const returns = () => sellerClient().orders.returns

  const create = usePostSaleMutation(
    orderId,
    key,
    (params: {
      items: Array<{ fulfillment_item_id: string; quantity: number }>
      memo?: string
      reason_id?: string
    }) => returns().create(orderId, params),
  )

  const approve = usePostSaleMutation(orderId, key, (id: string) => returns().approve(orderId, id))

  const receive = usePostSaleMutation(
    orderId,
    key,
    ({
      returnId,
      items,
    }: {
      returnId: string
      items?: Array<{ return_line_item_id: string; quantity: number; resellable?: boolean }>
    }) => returns().receive(orderId, returnId, items ? { items } : undefined),
  )

  const refund = usePostSaleMutation(
    orderId,
    key,
    ({
      returnId,
      refundMethod,
      amount,
    }: {
      returnId: string
      refundMethod?: 'original_payment' | 'store_credit'
      amount?: string
    }) => returns().refund(orderId, returnId, { refund_method: refundMethod, amount }),
  )

  const cancel = usePostSaleMutation(orderId, key, (id: string) => returns().cancel(orderId, id))

  return { create, approve, receive, refund, cancel }
}

export function useExchangeActions(orderId: string) {
  const key = 'seller-order-exchanges'
  const exchanges = () => sellerClient().orders.exchanges

  const create = usePostSaleMutation(
    orderId,
    key,
    (params: {
      items: Array<{ fulfillment_item_id: string; new_variant_id: string; quantity: number }>
      memo?: string
      reason_id?: string
    }) => exchanges().create(orderId, params),
  )

  const approve = usePostSaleMutation(orderId, key, (id: string) =>
    exchanges().approve(orderId, id),
  )

  const receive = usePostSaleMutation(
    orderId,
    key,
    ({
      exchangeId,
      items,
    }: {
      exchangeId: string
      items?: Array<{ exchange_line_item_id: string; quantity: number; resellable?: boolean }>
    }) => exchanges().receive(orderId, exchangeId, items ? { items } : undefined),
  )

  const fulfill = usePostSaleMutation(
    orderId,
    key,
    ({
      exchangeId,
      refundMethod,
    }: {
      exchangeId: string
      refundMethod?: 'original_payment' | 'store_credit'
    }) => exchanges().fulfill(orderId, exchangeId, { refund_method: refundMethod }),
  )

  const cancel = usePostSaleMutation(orderId, key, (id: string) => exchanges().cancel(orderId, id))

  return { create, approve, receive, fulfill, cancel }
}

export function useClaimActions(orderId: string) {
  const key = 'seller-order-claims'
  const claims = () => sellerClient().orders.claims

  const create = usePostSaleMutation(
    orderId,
    key,
    (params: {
      items: Array<{ line_item_id: string; quantity: number; description?: string }>
      memo?: string
      reason_id?: string
    }) => claims().create(orderId, params),
  )

  const approve = usePostSaleMutation(orderId, key, (id: string) => claims().approve(orderId, id))

  const resolve = usePostSaleMutation(
    orderId,
    key,
    ({
      claimId,
      resolution,
      refundMethod,
      amount,
      replacementLineItemIds,
    }: {
      claimId: string
      resolution: 'refund' | 'replacement' | 'refund_and_replacement'
      refundMethod?: 'original_payment' | 'store_credit'
      amount?: string
      replacementLineItemIds?: string[]
    }) =>
      claims().resolve(orderId, claimId, {
        resolution,
        refund_method: refundMethod,
        amount,
        replacement_line_item_ids: replacementLineItemIds,
      }),
  )

  const deny = usePostSaleMutation(orderId, key, (id: string) => claims().deny(orderId, id))
  const cancel = usePostSaleMutation(orderId, key, (id: string) => claims().cancel(orderId, id))

  return { create, approve, resolve, deny, cancel }
}
