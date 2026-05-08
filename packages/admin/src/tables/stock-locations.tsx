import type { StockLocation } from '@spree/admin-sdk'
import { WarehouseIcon } from 'lucide-react'
import { Badge } from '@/components/ui/badge'
import { defineTable } from '@/lib/table-registry'

defineTable<StockLocation>('stock-locations', {
  title: 'Stock Locations',
  searchParam: 'name_cont',
  searchPlaceholder: 'Search by name…',
  defaultSort: { field: 'name', direction: 'asc' },
  emptyIcon: <WarehouseIcon className="size-8 text-muted-foreground/50" />,
  emptyMessage: 'No stock locations yet',
  columns: [
    {
      key: 'name',
      label: 'Name',
      sortable: true,
      filterable: true,
      default: true,
      // The button carries `data-stock-location-id`. The route page mounts a
      // delegated click listener (RowClickBridge) that opens the edit Sheet
      // when any descendant marked with that attribute is clicked.
      render: (sl) => (
        <button
          type="button"
          data-stock-location-id={sl.id}
          className="flex flex-col items-start text-left hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring rounded"
        >
          <span className="font-medium">{sl.name}</span>
          {sl.admin_name && (
            <span data-stock-location-id={sl.id} className="text-xs text-muted-foreground">
              {sl.admin_name}
            </span>
          )}
        </button>
      ),
    },
    {
      key: 'kind',
      label: 'Type',
      sortable: true,
      filterable: true,
      default: true,
      filterType: 'status',
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
      render: (sl) =>
        sl.pickup_enabled ? <Badge variant="secondary">Enabled</Badge> : <span>—</span>,
    },
    {
      key: 'active',
      label: 'Active',
      sortable: true,
      filterable: true,
      default: true,
      filterType: 'boolean',
      render: (sl) =>
        sl.active ? <Badge variant="secondary">Active</Badge> : <Badge>Inactive</Badge>,
    },
    {
      key: 'default',
      label: 'Default',
      default: true,
      filterable: true,
      filterType: 'boolean',
      render: (sl) => (sl.default ? <Badge>Default</Badge> : '—'),
    },
  ],
})
