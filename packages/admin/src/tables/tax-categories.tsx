import type { TaxCategory } from '@spree/admin-sdk'
import { PercentIcon } from 'lucide-react'
import { ResourceNameCell } from '@/components/spree/resource-name-cell'
import { ActiveBadge } from '@/components/ui/badge'
import { defineTable } from '@/lib/table-registry'

defineTable<TaxCategory>('tax-categories', {
  title: 'Tax Categories',
  searchParam: 'name_cont',
  searchPlaceholder: 'Search by name…',
  defaultSort: { field: 'name', direction: 'asc' },
  emptyIcon: <PercentIcon className="size-8 text-muted-foreground" />,
  emptyMessage: 'No tax categories yet',
  columns: [
    {
      key: 'name',
      label: 'Name',
      sortable: true,
      filterable: true,
      default: true,
      render: (tc) => (
        <ResourceNameCell
          id={tc.id}
          dataAttr="data-tax-category-id"
          name={tc.name}
          secondary={tc.description}
        />
      ),
    },
    {
      key: 'tax_code',
      label: 'Tax code',
      sortable: true,
      filterable: true,
      default: true,
      render: (tc) => tc.tax_code ?? '—',
    },
    {
      key: 'is_default',
      label: 'Default',
      default: true,
      render: (tc) => <ActiveBadge active={tc.is_default} activeLabel="Default" dashWhenInactive />,
    },
  ],
})
