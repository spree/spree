import { defineTable } from '@spree/dashboard-core'
import { ResourceNameCell, StatusBadge, Thumbnail } from '@spree/dashboard-ui'
import type { Product } from '@spree/seller-sdk'
import i18n from 'i18next'
import { PackageIcon } from 'lucide-react'

defineTable<Product>('seller-products', {
  title: i18n.t('products.title'),
  searchParam: 'name_cont',
  searchPlaceholder: i18n.t('products.search_placeholder'),
  defaultSort: { field: 'created_at', direction: 'desc' },
  emptyIcon: <PackageIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('products.empty'),
  columns: [
    {
      key: 'name',
      label: i18n.t('products.columns.name'),
      sortable: true,
      filterable: true,
      default: true,
      render: (product) => (
        <div className="flex items-center gap-3">
          <Thumbnail src={product.thumbnail_url} alt={product.name} />
          <ResourceNameCell id={product.id} dataAttr="data-product-id" name={product.name} />
        </div>
      ),
    },
    {
      key: 'status',
      label: i18n.t('products.columns.status'),
      sortable: true,
      default: true,
      render: (product) => (
        <StatusBadge
          status={product.status}
          label={i18n.t(`products.statuses.${product.status}`)}
        />
      ),
    },
    {
      key: 'price',
      label: i18n.t('products.columns.price'),
      default: true,
      render: (product) => product.price?.display_amount ?? '—',
    },
  ],
})
