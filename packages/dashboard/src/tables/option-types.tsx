import type { OptionType } from '@spree/admin-sdk'
import { ActiveBadge, Badge, RelativeTime, ResourceNameCell } from '@spree/dashboard-ui'
import { ListChecksIcon } from 'lucide-react'
import { defineTable } from '@/lib/table-registry'

const KIND_LABELS: Record<string, string> = {
  dropdown: 'Dropdown',
  color_swatch: 'Color swatch',
  buttons: 'Buttons',
}

defineTable<OptionType>('option-types', {
  title: 'Option Types',
  searchParam: 'name_cont',
  searchPlaceholder: 'Search by name…',
  defaultSort: { field: 'position', direction: 'asc' },
  emptyIcon: <ListChecksIcon className="size-8 text-muted-foreground" />,
  emptyMessage: 'No option types yet',
  columns: [
    {
      key: 'name',
      label: 'Name',
      sortable: true,
      filterable: true,
      default: true,
      render: (ot) => (
        <ResourceNameCell
          id={ot.id}
          dataAttr="data-option-type-id"
          name={ot.name}
          secondary={ot.label && ot.label !== ot.name ? ot.label : undefined}
        />
      ),
    },
    {
      key: 'kind',
      label: 'Kind',
      sortable: true,
      filterable: true,
      filterType: 'enum',
      filterOptions: Object.entries(KIND_LABELS).map(([value, label]) => ({ value, label })),
      default: true,
      render: (ot) => <Badge variant="secondary">{KIND_LABELS[ot.kind] ?? ot.kind}</Badge>,
    },
    {
      key: 'option_values',
      label: 'Values',
      default: true,
      render: (ot) => {
        const count = ot.option_values?.length ?? 0
        return (
          <span className="text-sm text-muted-foreground">
            {count === 1 ? '1 value' : `${count} values`}
          </span>
        )
      },
    },
    {
      key: 'filterable',
      label: 'Filterable',
      default: true,
      render: (ot) => <ActiveBadge active={ot.filterable ?? false} dashWhenInactive />,
    },
    {
      key: 'updated_at',
      label: 'Updated',
      sortable: true,
      render: (ot) => <RelativeTime iso={ot.updated_at} />,
    },
  ],
})
