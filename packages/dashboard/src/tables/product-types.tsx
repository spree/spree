import type { ProductType } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { Badge, ResourceNameCell } from '@spree/dashboard-ui'
import i18n from 'i18next'
import { ShapesIcon } from 'lucide-react'

defineTable<ProductType>('product-types', {
  title: i18n.t('admin.settings_nav.items.product_types'),
  searchParam: 'name_cont',
  searchPlaceholder: i18n.t('admin.product_types.search_placeholder'),
  defaultSort: { field: 'name', direction: 'asc' },
  emptyIcon: <ShapesIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.product_types.empty'),
  columns: [
    {
      key: 'name',
      label: i18n.t('admin.fields.name.label'),
      sortable: true,
      filterable: true,
      default: true,
      render: (productType) => (
        <ResourceNameCell
          id={productType.id}
          dataAttr="data-product-type-id"
          name={productType.name}
        />
      ),
    },
    {
      key: 'fulfillment_types',
      label: i18n.t('admin.fields.product_type.fulfillment_types.label'),
      default: true,
      render: (productType) => (
        <div className="flex flex-wrap gap-1">
          {(productType.fulfillment_types ?? []).map((fulfillmentType) => (
            <Badge key={fulfillmentType} variant="secondary">
              {i18n.t(`admin.delivery_methods.fulfillment_types.${fulfillmentType}`, {
                defaultValue: fulfillmentType,
              })}
            </Badge>
          ))}
        </div>
      ),
    },
    {
      key: 'products_count',
      label: i18n.t('admin.fields.product_type.products_count.label'),
      default: true,
      render: (productType) => productType.products_count,
    },
  ],
})
