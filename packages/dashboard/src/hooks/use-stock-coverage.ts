import { adminClient, useResourceKey } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'

/** How many units of a variant a fulfillment needs. */
export interface VariantDemand {
  variantId: string
  quantity: number
}

/**
 * Which stock locations can cover a set of variants, keyed by location id.
 * A location missing from the map holds no stock item for at least one of the
 * variants at all, which counts as not covering it.
 */
export type StockCoverage = Map<string, boolean>

/**
 * Asks, for every stock location, whether it could source the given variants.
 *
 * One request covers the whole question: stock items are fetched for all the
 * variants at once and grouped by location afterwards, so opening a dialog
 * costs a single round trip rather than one per row. A backorderable item
 * counts as covered — that is the point of the flag, and Spree will happily
 * ship a fulfillment from a warehouse awaiting a transfer.
 */
export function useStockCoverage(demands: VariantDemand[], enabled = true) {
  const variantIds = demands.map((demand) => demand.variantId).sort()

  return useQuery({
    queryKey: useResourceKey('stock-items', 'coverage', variantIds),
    enabled: enabled && variantIds.length > 0,
    queryFn: async (): Promise<StockCoverage> => {
      const response = await adminClient.stockItems.list({
        variant_id_in: variantIds,
        // A variant can exist at every location, so the ceiling is
        // variants × locations. The API caps `limit` at 100; merchants with
        // more rows than that get the first page, and an unseen location
        // simply reads as uncovered rather than wrongly reading as covered.
        limit: 100,
      })

      return computeStockCoverage(response.data, demands)
    },
  })
}

/** The stock-item fields the coverage computation reads. */
export interface CoverageStockItem {
  stock_location_id?: string | null
  variant_id?: string | null
  available_count: number
  backorderable: boolean
}

/**
 * Groups stock rows by location and asks whether each location holds enough of
 * every demanded variant. Backorderable rows count as unlimited: that flag
 * exists so Spree can ship from an empty shelf.
 *
 * A location with no row for one of the variants cannot cover it — the caller
 * labels those "Out of stock" rather than hiding them, so a warehouse awaiting
 * a transfer stays selectable.
 */
export function computeStockCoverage(
  stockItems: CoverageStockItem[],
  demands: VariantDemand[],
): StockCoverage {
  const availabilityByLocation = new Map<string, Map<string, number>>()

  for (const stockItem of stockItems) {
    if (!stockItem.stock_location_id || !stockItem.variant_id) continue

    const perVariant =
      availabilityByLocation.get(stockItem.stock_location_id) ?? new Map<string, number>()
    perVariant.set(
      stockItem.variant_id,
      stockItem.backorderable ? Number.POSITIVE_INFINITY : stockItem.available_count,
    )
    availabilityByLocation.set(stockItem.stock_location_id, perVariant)
  }

  const coverage: StockCoverage = new Map()
  for (const [locationId, perVariant] of availabilityByLocation) {
    coverage.set(
      locationId,
      demands.every((demand) => (perVariant.get(demand.variantId) ?? 0) >= demand.quantity),
    )
  }

  return coverage
}
