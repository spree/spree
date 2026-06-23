import type { StockLocation } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { ActiveBadge, ResourceNameCell } from '@spree/dashboard-ui'
import i18n from 'i18next'
import { WarehouseIcon } from 'lucide-react'

defineTable<StockLocation>('stock-locations', {
  title: i18n.t('admin.settings_nav.items.stock_locations'),
  searchParam: 'name_cont',
  searchPlaceholder: i18n.t('admin.stock_locations.search_placeholder'),
  defaultSort: { field: 'name', direction: 'asc' },
  emptyIcon: <WarehouseIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.stock_locations.empty'),
  columns: [
    {
      key: 'name',
      label: i18n.t('admin.fields.name.label'),
      sortable: true,
      filterable: true,
      default: true,
      render: (sl) => (
        <ResourceNameCell
          id={sl.id}
          dataAttr="data-stock-location-id"
          name={sl.name}
          secondary={sl.admin_name}
        />
      ),
    },
    {
      key: 'kind',
      label: i18n.t('admin.stock_locations.columns.type'),
      sortable: true,
      filterable: true,
      default: true,
      filterType: 'enum',
      filterOptions: [
        { value: 'warehouse', label: i18n.t('admin.stock_locations.kinds.warehouse') },
        { value: 'store', label: i18n.t('admin.stock_locations.kinds.store') },
        {
          value: 'fulfillment_center',
          label: i18n.t('admin.stock_locations.kinds.fulfillment_center'),
        },
      ],
      render: (sl) => {
        const key = `admin.stock_locations.kinds.${sl.kind}`
        const label = i18n.exists(key) ? i18n.t(key) : sl.kind.replace('_', ' ')
        return <span className="capitalize">{label}</span>
      },
    },
    {
      key: 'city',
      label: i18n.t('admin.stock_locations.columns.location'),
      default: true,
      render: (sl) => {
        const parts = [sl.city, sl.state_text || sl.state_abbr, sl.country_iso]
          .filter(Boolean)
          .join(', ')
        return parts || '—'
      },
    },
    {
      key: 'pickup_enabled',
      label: i18n.t('admin.stock_locations.columns.pickup'),
      sortable: true,
      filterable: true,
      default: true,
      filterType: 'boolean',
      render: (sl) => (
        <ActiveBadge
          active={sl.pickup_enabled}
          activeLabel={i18n.t('admin.stock_locations.badges.enabled')}
          dashWhenInactive
        />
      ),
    },
    {
      key: 'active',
      label: i18n.t('admin.fields.active.label'),
      sortable: true,
      filterable: true,
      default: true,
      filterType: 'boolean',
      render: (sl) => (
        <ActiveBadge
          active={sl.active}
          activeLabel={i18n.t('admin.fields.active.label')}
          inactiveLabel={i18n.t('admin.stock_locations.badges.inactive')}
        />
      ),
    },
    {
      key: 'default',
      label: i18n.t('admin.stock_locations.columns.default'),
      default: true,
      filterable: true,
      filterType: 'boolean',
      render: (sl) => (
        <ActiveBadge
          active={sl.default}
          activeLabel={i18n.t('admin.stock_locations.badges.default')}
          dashWhenInactive
        />
      ),
    },
  ],
})
