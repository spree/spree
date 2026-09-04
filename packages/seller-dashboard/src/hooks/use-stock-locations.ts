import { useResourceKey } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'
import { sellerClient } from '../api-client'

/**
 * Where this seller keeps stock.
 *
 * Deliberately not `useStockLocations` from `@spree/dashboard-core`: that one
 * reads the admin client and would answer with the marketplace's warehouses
 * too, so a seller moving a parcel could pick a shelf that is not theirs. The
 * seller endpoint is rooted in `current_seller.stock_locations`, so the list
 * is theirs by construction rather than by filtering here.
 *
 * Slow-moving, so one fetch serves every dialog on the page.
 */
export function useStockLocations(enabled = true) {
  return useQuery({
    queryKey: useResourceKey('seller-stock-locations'),
    queryFn: () => sellerClient().stockLocations.list({ limit: 100 }),
    staleTime: 5 * 60 * 1000,
    enabled,
  })
}
