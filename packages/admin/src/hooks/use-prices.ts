import type { PriceBulkUpsertRow } from '@spree/admin-sdk'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { adminClient } from '@/client'

/**
 * Mutation hook for the bulk-upsert endpoint behind the price spreadsheet.
 * Invalidates every `prices` query so cards that show price counts (price
 * list "N prices configured" hints, base-price grids on other surfaces)
 * refetch automatically. Toasts and form-error mapping live in the caller
 * so the spreadsheet can render its own dirty-state UI on failure.
 */
export function useBulkUpsertPrices() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (params: { prices: PriceBulkUpsertRow[] }) => adminClient.prices.bulkUpsert(params),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['prices'] })
    },
  })
}
