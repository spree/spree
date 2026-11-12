import { PRODUCT_STATUSES } from '@spree/core'
import { defineTable, formatPrice, ProductStockSummary } from '@spree/dashboard-core'
import { ProductIdentity, StatusBadge } from '@spree/dashboard-ui'
import { PackageIcon } from '@spree/dashboard-ui/icons'
import type { Product } from '@spree/seller-sdk'
import i18n from 'i18next'

defineTable<Product>('seller-products', {
  title: i18n.t('products.title'),
  searchParam: 'search',
  searchPlaceholder: i18n.t('products.search_placeholder'),
  defaultSort: { field: 'created_at', direction: 'desc' },
  emptyIcon: <PackageIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('products.empty'),
  columns: [
    {
      key: 'name',
      label: i18n.t('products.columns.name'),
      sortable: true,
      default: true,
      render: (product) => (
        <ProductIdentity
          name={product.name}
          thumbnailUrl={product.thumbnail_url}
          render={<button type="button" data-product-id={product.id} />}
        />
      ),
    },
    {
      key: 'status',
      label: i18n.t('products.columns.status'),
      sortable: true,
      filterable: true,
      filterType: 'enum',
      filterOptions: PRODUCT_STATUSES.map((status) => ({
        value: status,
        label: i18n.t(`products.statuses.${status}`),
      })),
      quickFilter: true,
      default: true,
      render: (product) => (
        <StatusBadge
          status={product.status}
          label={i18n.t(`products.statuses.${product.status}`)}
        />
      ),
    },
    {
      key: 'inventory',
      label: i18n.t('products.columns.inventory'),
      default: true,
      render: (product) => <ProductStockSummary product={product} />,
    },
    {
      key: 'price',
      label: i18n.t('products.columns.price'),
      default: true,
      render: (product) => formatPrice(product.price ?? null),
    },
  ],
})
