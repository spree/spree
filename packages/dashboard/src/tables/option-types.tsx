import type { OptionType } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { ActiveBadge, Badge, ResourceNameCell } from '@spree/dashboard-ui'
import i18n from 'i18next'
import { ListChecksIcon } from 'lucide-react'

const KIND_LABELS: Record<string, string> = {
  dropdown: i18n.t('admin.option_types.kinds.dropdown'),
  color_swatch: i18n.t('admin.option_types.kinds.color_swatch'),
  buttons: i18n.t('admin.option_types.kinds.buttons'),
}

defineTable<OptionType>('option-types', {
  title: i18n.t('admin.nav.options'),
  searchParam: 'name_cont',
  searchPlaceholder: i18n.t('admin.option_types.table.search_placeholder'),
  defaultSort: { field: 'position', direction: 'asc' },
  emptyIcon: <ListChecksIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.option_types.table.empty'),
  columns: [
    {
      key: 'name',
      label: i18n.t('admin.fields.name.label'),
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
      label: i18n.t('admin.fields.kind.label'),
      sortable: true,
      filterable: true,
      filterType: 'enum',
      filterOptions: Object.entries(KIND_LABELS).map(([value, label]) => ({ value, label })),
      default: true,
      render: (ot) => <Badge variant="secondary">{KIND_LABELS[ot.kind] ?? ot.kind}</Badge>,
    },
    {
      key: 'option_values',
      label: i18n.t('admin.option_types.columns.values'),
      default: true,
      render: (ot) => {
        const count = ot.option_values?.length ?? 0
        return (
          <span className="text-sm text-muted-foreground">
            {i18n.t('admin.option_types.value_count', { count })}
          </span>
        )
      },
    },
    {
      key: 'filterable',
      label: i18n.t('admin.fields.option_type.filterable.label'),
      default: true,
      render: (ot) => <ActiveBadge active={ot.filterable ?? false} dashWhenInactive />,
    },
  ],
})
