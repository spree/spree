import { useResourceKey } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'
import { sellerClient } from '../api-client'

/**
 * Where this seller stands, one row per currency.
 *
 * Nothing is ever converted between currencies, so a seller trading in two
 * has two positions and the panel shows both rather than a total.
 */
export function useBalances() {
  return useQuery({
    queryKey: useResourceKey('seller-balances'),
    queryFn: () => sellerClient().balances.list(),
  })
}

/** One settlement, for its own page. */
export function usePayout(payoutId: string) {
  return useQuery({
    queryKey: useResourceKey('seller-payout', payoutId),
    queryFn: () => sellerClient().payouts.get(payoutId),
    enabled: !!payoutId,
  })
}

/**
 * The earnings a settlement covers, or the ones an order produced.
 *
 * Both read the same list filtered a different way, so the pages that ask
 * either question share one hook and one query key shape.
 *
 * Paged rather than capped: the server clamps `limit` at 100, and a payout
 * covering more than that must not render one page and call it the whole
 * settlement.
 */
export function useTransfers(filter: { payout_id_eq?: string; order_id_eq?: string }, page = 1) {
  const key = filter.payout_id_eq ?? filter.order_id_eq ?? 'all'

  return useQuery({
    queryKey: useResourceKey('seller-transfers', key, String(page)),
    queryFn: () => sellerClient().transfers.list({ ...filter, limit: 100, page }),
    enabled: !!(filter.payout_id_eq || filter.order_id_eq),
    placeholderData: (previous) => previous,
  })
}
