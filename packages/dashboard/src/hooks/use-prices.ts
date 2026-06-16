import type { PriceBulkUpsertRow } from '@spree/admin-sdk'
import { adminClient, useResourceMutation } from '@spree/dashboard-core'

/**
 * Mutation hook for the bulk-upsert endpoint behind the price spreadsheet.
 * Invalidates every `prices` query so cards that show price counts (price
 * list "N prices configured" hints, base-price grids on other surfaces)
 * refetch automatically. Toasts and form-error mapping live in the caller
 * so the spreadsheet can render its own dirty-state UI on failure.
 *
 * Amounts arrive already normalized to canonical `"1234.56"` form — the editor
 * converts the merchant's localized input client-side (see
 * docs/plans/5.5-client-side-money-normalization.md), so no request locale.
 */
export function useBulkUpsertPrices() {
  return useResourceMutation<{ price_count: number }, Error, { prices: PriceBulkUpsertRow[] }>({
    mutationFn: (params) => adminClient.prices.bulkUpsert(params),
    invalidate: [['prices']],
    successMessage: false,
    errorMessage: false,
  })
}
