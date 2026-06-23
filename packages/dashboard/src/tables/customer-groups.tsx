import type { CustomerGroup } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { ResourceNameCell } from '@spree/dashboard-ui'
import i18n from 'i18next'
import { UsersRoundIcon } from 'lucide-react'

defineTable<CustomerGroup>('customer-groups', {
  title: i18n.t('admin.customers.groups.table.title'),
  searchParam: 'name_cont',
  searchPlaceholder: i18n.t('admin.customers.groups.table.search_placeholder'),
  defaultSort: { field: 'name', direction: 'asc' },
  emptyIcon: <UsersRoundIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.customers.groups.table.empty'),
  columns: [
    {
      key: 'name',
      label: i18n.t('admin.fields.name.label'),
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
      label: i18n.t('admin.customers.groups.columns.customers'),
      sortable: true,
      default: true,
      render: (g) => g.customers_count,
    },
  ],
})
