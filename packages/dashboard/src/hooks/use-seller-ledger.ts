import { adminClient, useResourceKey, useResourceMutation } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'
import i18n from 'i18next'

/** Where one seller stands with the marketplace, one row per currency. */
export function useSellerBalances(sellerId: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('sellers', sellerId ?? 'noop', 'balances'),
    queryFn: () => adminClient.sellers.balances(sellerId as string),
    enabled: !!sellerId,
  })
}

export function usePayout(payoutId: string) {
  return useQuery({
    queryKey: useResourceKey('seller-payouts', payoutId),
    queryFn: () => adminClient.sellerPayouts.get(payoutId),
    enabled: !!payoutId,
  })
}

/**
 * The earnings one settlement covers, or the ones one order produced.
 *
 * Read through the transfers list rather than off the payout: a settlement
 * carries only the count, and a monthly one can hold hundreds of rows that
 * only this page wants.
 *
 * Paged rather than capped. The server clamps `limit` at 100, so a sweep
 * covering more than that would otherwise render a page and call it the
 * whole settlement — on the screen whose purpose is tracing a bank figure
 * back to the sales behind it.
 */
export function useSellerTransfers(
  filter: { payout_id_eq?: string; order_id_eq?: string },
  page = 1,
) {
  const key = filter.payout_id_eq ?? filter.order_id_eq ?? 'all'

  return useQuery({
    queryKey: useResourceKey('seller-transfers', key, String(page)),
    queryFn: () => adminClient.sellerTransfers.list({ ...filter, limit: 100, page }),
    enabled: !!(filter.payout_id_eq || filter.order_id_eq),
    placeholderData: (previous) => previous,
  })
}

/**
 * The operator saying a bank transfer went out.
 *
 * What the built-in payout provider waits for: it records what to send and is
 * then told it went, with the reference it went out under.
 */
export function useCompletePayout(payoutId: string) {
  return useResourceMutation({
    mutationFn: (params: { reference?: string }) =>
      adminClient.sellerPayouts.complete(payoutId, params),
    invalidate: [['seller-payouts'], ['seller-payouts', payoutId], ['sellers']],
    successMessage: i18n.t('admin.payouts.marked_paid'),
  })
}

/**
 * The payments a split checkout was paid with.
 *
 * Narrowed with `fields`, not just `expand`: the group serializer renders the
 * orders it holds through the full admin order serializer, so a five-seller
 * basket would otherwise pull five complete sibling orders — items, addresses
 * and fulfillments included — to read one payments array.
 */
export function useOrderGroup(orderGroupId: string | null | undefined) {
  return useQuery({
    queryKey: useResourceKey('order-groups', orderGroupId ?? 'noop', 'payments'),
    queryFn: () =>
      adminClient.orderGroups.get(orderGroupId as string, {
        fields: ['payments', 'number'],
      }),
    enabled: !!orderGroupId,
  })
}
