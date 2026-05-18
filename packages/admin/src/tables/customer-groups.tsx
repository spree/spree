import type { CustomerGroup } from '@spree/admin-sdk'
import { UsersRoundIcon } from 'lucide-react'
import { ResourceNameCell } from '@/components/spree/resource-name-cell'
import { defineTable } from '@/lib/table-registry'

defineTable<CustomerGroup>('customer-groups', {
  title: 'Customer Groups',
  searchParam: 'name_cont',
  searchPlaceholder: 'Search by name…',
  defaultSort: { field: 'name', direction: 'asc' },
  emptyIcon: <UsersRoundIcon className="size-8 text-muted-foreground" />,
  emptyMessage: 'No customer groups yet',
  columns: [
    {
      key: 'name',
      label: 'Name',
      sortable: true,
      filterable: true,
      default: true,
      render: (g) => (
        <ResourceNameCell
          id={g.id}
          dataAttr="data-customer-group-id"
          name={g.name}
          secondary={g.description ?? undefined}
        />
      ),
    },
    {
      key: 'customers_count',
      label: 'Customers',
      sortable: true,
      default: true,
      render: (g) => g.customers_count,
    },
  ],
})
