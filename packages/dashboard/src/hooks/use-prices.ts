import type { PriceBulkUpsertRow } from '@spree/admin-sdk'
import { adminClient, useResourceMutation } from '@spree/dashboard-core'

/**
 * Mutation hook for the bulk-upsert endpoint behind the price spreadsheet.
 * Invalidates every `prices` query so cards that show price counts (price
 * list "N prices configured" hints, base-price grids on other surfaces)
 * refetch automatically. Toasts and form-error mapping live in the caller
 * so the spreadsheet can render its own dirty-state UI on failure.
 */
export function useBulkUpsertPrices() {
  return useResourceMutation<{ price_count: number }, Error, { prices: PriceBulkUpsertRow[] }>({
    mutationFn: (params) => adminClient.prices.bulkUpsert(params),
    invalidate: [['prices']],
    successMessage: false,
    errorMessage: false,
  })
}
