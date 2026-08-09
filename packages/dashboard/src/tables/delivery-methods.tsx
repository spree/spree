import type { DeliveryMethod } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { ActiveBadge, Badge, ResourceNameCell } from '@spree/dashboard-ui'
import i18n from 'i18next'
import { TruckIcon } from 'lucide-react'

defineTable<DeliveryMethod>('delivery-methods', {
  title: i18n.t('admin.settings_nav.items.delivery_methods'),
  searchParam: 'name_cont',
  searchPlaceholder: i18n.t('admin.delivery_methods.search_placeholder'),
  defaultSort: { field: 'name', direction: 'asc' },
  emptyIcon: <TruckIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.delivery_methods.empty'),
  columns: [
    {
      key: 'name',
      label: i18n.t('admin.fields.name.label'),
      sortable: true,
      filterable: true,
      default: true,
      render: (dm) => (
        <ResourceNameCell
          id={dm.id}
          dataAttr="data-delivery-method-id"
          name={dm.name}
          secondary={dm.admin_name}
        />
      ),
    },
    {
      key: 'fulfillment_type',
      label: i18n.t('admin.fields.delivery_method.fulfillment_type.label'),
      default: true,
      render: (dm) => (
        <Badge variant="outline">
          {i18n.t(`admin.delivery_methods.fulfillment_types.${dm.fulfillment_type}`, {
            defaultValue: dm.fulfillment_type,
          })}
        </Badge>
      ),
    },
    {
      key: 'storefront_visible',
      label: i18n.t('admin.fields.storefront_visible.label'),
      default: true,
      render: (dm) => (
        <ActiveBadge
          active={dm.storefront_visible}
          activeLabel={i18n.t('admin.fields.storefront_visible.label')}
          dashWhenInactive
        />
      ),
    },
  ],
})
