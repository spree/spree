import type { Product, Seller } from '@spree/admin-sdk'
import {
  adminClient,
  ResourceTable,
  Subject,
  useEmbeddedTableSearch,
  usePermissions,
} from '@spree/dashboard-core'
import { Badge, Section, SectionHeader, SectionTitle } from '@spree/dashboard-ui'
import { PackageIcon } from '@spree/dashboard-ui/icons'
import { useTranslation } from 'react-i18next'
import '../../../tables/products'
import { ProductReviewActions } from '../products/product-review-actions'

/** The products list, narrowed to this seller and, optionally, one status. */
export function sellerProductsSearch(sellerId: string, status?: string) {
  return {
    filters: [
      { id: 'seller', field: 'seller', operator: 'in', value: sellerId },
      ...(status ? [{ id: 'status', field: 'status', operator: 'in', value: status }] : []),
    ],
  }
}

/**
 * The seller's products, as the products list shows them. Products in review
 * are approved or sent back in place.
 */
export function SellerProductsSection({ seller }: { seller: Seller }) {
  const { t } = useTranslation()
  const { permissions } = usePermissions()
  const table = useEmbeddedTableSearch({ limit: 10 })
  const canReview = permissions.can('update', Subject.Product)

  return (
    <Section>
      <SectionHeader>
        <SectionTitle>
          <PackageIcon />
          {t('admin.nav.products')}
          {seller.products_count > 0 && <Badge variant="outline">{seller.products_count}</Badge>}
        </SectionTitle>
      </SectionHeader>

      <ResourceTable<Product>
        tableKey="products"
        queryKey={['products', 'seller', seller.id]}
        queryFn={(params) => adminClient.products.list(params)}
        {...table}
        hideHeader
        framed
        defaultParams={{ seller_id_eq: seller.id }}
        hiddenColumns={['seller']}
        rowActions={
          canReview
            ? (product) =>
                product.status === 'proposed' ? (
                  <div className="flex justify-end gap-2">
                    <ProductReviewActions productId={product.id} status={product.status} />
                  </div>
                ) : null
            : undefined
        }
      />
    </Section>
  )
}
