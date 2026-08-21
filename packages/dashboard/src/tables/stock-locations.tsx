import type { StockLocation } from '@spree/admin-sdk'
import { tables } from '@spree/dashboard-core'
import { Badge } from '@spree/dashboard-ui'
import i18n from 'i18next'
import { sellerAutocompleteProps } from '../hooks/use-sellers'

/**
 * Adds one column to the shared stock-locations table: whose location a row
 * is.
 *
 * It belongs to the operator alone. On a marketplace their list holds their
 * own locations and every seller's together, and without this the two are
 * indistinguishable — while in a seller's panel every row is theirs already,
 * so the column would repeat the page's own subject on every line.
 *
 * A column added to the shared definition rather than a second table: the
 * registry exists for exactly this, and a fork would have to be kept in step
 * with the original by hand.
 */
tables['stock-locations'].addColumn<StockLocation>({
  key: 'seller_id',
  label: i18n.t('admin.stock_locations.columns.seller'),
  default: true,
  filterable: true,
  filterType: 'resource',
  // `seller_id_in` — whitelisted on StockLocation alongside the `seller`
  // association, so the filter narrows to one or more sellers.
  ransackAttribute: 'seller_id',
  filterResource: sellerAutocompleteProps('stock-location-seller-picker'),
  render: (location) =>
    location.seller_name ? <Badge variant="outline">{location.seller_name}</Badge> : '—',
})
