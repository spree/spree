import type { StockLocation } from '@spree/admin-sdk'
import { WarehouseIcon } from 'lucide-react'
import { ResourceNameCell } from '@/components/spree/resource-name-cell'
import { ActiveBadge } from '@/components/ui/badge'
import { defineTable } from '@/lib/table-registry'

defineTable<StockLocation>('stock-locations', {
  title: 'Stock Locations',
  searchParam: 'name_cont',
  searchPlaceholder: 'Search by name…',
  defaultSort: { field: 'name', direction: 'asc' },
  emptyIcon: <WarehouseIcon className="size-8 text-muted-foreground" />,
  emptyMessage: 'No stock locations yet',
  columns: [
    {
      key: 'name',
      label: 'Name',
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
      label: 'Type',
      sortable: true,
      filterable: true,
      default: true,
      filterType: 'enum',
      filterOptions: [
        { value: 'warehouse', label: 'Warehouse' },
        { value: 'store', label: 'Store' },
        { value: 'fulfillment_center', label: 'Fulfillment center' },
      ],
      render: (sl) => <span className="capitalize">{sl.kind.replace('_', ' ')}</span>,
    },
    {
      key: 'city',
      label: 'Location',
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
      label: 'Pickup',
      sortable: true,
      filterable: true,
      default: true,
      filterType: 'boolean',
      render: (sl) => (
        <ActiveBadge active={sl.pickup_enabled} activeLabel="Enabled" dashWhenInactive />
      ),
    },
    {
      key: 'active',
      label: 'Active',
      sortable: true,
      filterable: true,
      default: true,
      filterType: 'boolean',
      render: (sl) => (
        <ActiveBadge active={sl.active} activeLabel="Active" inactiveLabel="Inactive" />
      ),
    },
    {
      key: 'default',
      label: 'Default',
      default: true,
      filterable: true,
      filterType: 'boolean',
      render: (sl) => <ActiveBadge active={sl.default} activeLabel="Default" dashWhenInactive />,
    },
  ],
})
