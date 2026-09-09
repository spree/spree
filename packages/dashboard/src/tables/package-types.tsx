import type { PackageType } from '@spree/admin-sdk'
import { tables } from '@spree/dashboard-core'
import { Badge } from '@spree/dashboard-ui'
import i18n from 'i18next'
import { sellerAutocompleteProps } from '../hooks/use-sellers'

/**
 * Adds one column to the shared package-types table: whose packaging a row is.
 *
 * It belongs to the operator alone. On a marketplace their list holds the
 * marketplace's own boxes and every seller's together, and without this the
 * two are indistinguishable — while in a seller's panel the list is their own
 * rows plus the marketplace's, which the read-only rows already say.
 *
 * A column added to the shared definition rather than a second table: the
 * registry exists for exactly this, and a fork would have to be kept in step
 * with the original by hand.
 */
tables['package-types'].addColumn<PackageType>({
  key: 'seller_id',
  label: i18n.t('admin.package_types.columns.seller'),
  default: true,
  filterable: true,
  filterType: 'resource',
  // `seller_id` — whitelisted on PackageType alongside the `seller`
  // association, so the filter narrows to one or more sellers.
  //
  // It cannot yet ask for "the marketplace's own" (a null owner): the
  // resource filter emits ids only, and asking for NULL needs a scope and a
  // filter type neither this table nor the stock-locations column beside it
  // has. The column still labels those rows, so they are readable if not
  // filterable.
  ransackAttribute: 'seller_id',
  filterResource: sellerAutocompleteProps('package-type-seller-picker'),
  render: (packageType) =>
    packageType.seller_name ? (
      <Badge variant="outline">{packageType.seller_name}</Badge>
    ) : (
      i18n.t('admin.package_types.owner.marketplace')
    ),
})
