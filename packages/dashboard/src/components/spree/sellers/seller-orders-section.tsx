import type { Order, Seller } from '@spree/admin-sdk'
import { adminClient, ResourceTable, useEmbeddedTableSearch } from '@spree/dashboard-core'
import { Section, SectionHeader, SectionTitle } from '@spree/dashboard-ui'
import { ShoppingCartIcon } from '@spree/dashboard-ui/icons'
import { useTranslation } from 'react-i18next'
import '../../../tables/orders'

// The page is the seller; channel and item count are left to the full list
// so the total fits beside the sidebar.
const HIDDEN_COLUMNS = ['seller', 'channel', 'total_quantity']

/** The orders list, narrowed to this seller and, optionally, to what is left to ship. */
export function sellerOrdersSearch(sellerId: string, toFulfill = false) {
  return {
    filters: [
      { id: 'seller', field: 'seller', operator: 'in', value: sellerId },
      ...(toFulfill
        ? [
            {
              id: 'fulfillment_status',
              field: 'fulfillment_status',
              operator: 'in',
              value: 'unfulfilled',
            },
          ]
        : []),
    ],
  }
}

/**
 * The seller's placed orders, as the orders list shows them.
 */
export function SellerOrdersSection({ seller }: { seller: Seller }) {
  const { t } = useTranslation()
  const table = useEmbeddedTableSearch({ limit: 10 })

  return (
    <Section>
      <SectionHeader>
        <SectionTitle>
          <ShoppingCartIcon />
          {t('admin.nav.orders')}
        </SectionTitle>
      </SectionHeader>

      <ResourceTable<Order>
        tableKey="orders"
        queryKey={['orders', 'seller', seller.id]}
        queryFn={(params) => adminClient.orders.list(params)}
        {...table}
        hideHeader
        framed
        defaultParams={{ complete: 1, seller_id_eq: seller.id }}
        hiddenColumns={HIDDEN_COLUMNS}
      />
    </Section>
  )
}
