import type { DeliveryZone } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { ResourceNameCell } from '@spree/dashboard-ui'
import i18n from 'i18next'
import { MapIcon } from 'lucide-react'

defineTable<DeliveryZone>('delivery-zones', {
  title: i18n.t('admin.settings_nav.items.delivery_zones'),
  searchParam: 'name_cont',
  searchPlaceholder: i18n.t('admin.delivery_zones.search_placeholder'),
  defaultSort: { field: 'name', direction: 'asc' },
  emptyIcon: <MapIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.delivery_zones.empty'),
  columns: [
    {
      key: 'name',
      label: i18n.t('admin.fields.name.label'),
      sortable: true,
      filterable: true,
      default: true,
      render: (zone) => (
        <ResourceNameCell
          id={zone.id}
          dataAttr="data-delivery-zone-id"
          name={zone.name}
          secondary={zone.description}
        />
      ),
    },
    {
      key: 'members',
      label: i18n.t('admin.delivery_zones.members_column'),
      default: true,
      render: (zone) =>
        i18n.t('admin.delivery_zones.members_count', { count: zone.members?.length ?? 0 }),
    },
  ],
})
