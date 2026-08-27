import { defineTable } from '@spree/dashboard-core'
import { RelativeTime, ResourceNameCell } from '@spree/dashboard-ui'
import type { Policy } from '@spree/seller-sdk'
import i18n from 'i18next'
import { ScrollTextIcon } from 'lucide-react'

defineTable<Policy>('seller-policies', {
  title: i18n.t('policies.title'),
  searchParam: 'name_cont',
  searchPlaceholder: i18n.t('policies.search_placeholder'),
  defaultSort: { field: 'name', direction: 'asc' },
  emptyIcon: <ScrollTextIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('policies.empty.title'),
  columns: [
    {
      key: 'name',
      label: i18n.t('policies.columns.name'),
      sortable: true,
      filterable: true,
      default: true,
      render: (policy) => (
        <ResourceNameCell
          id={policy.id}
          dataAttr="data-policy-id"
          name={policy.name}
          secondary={policy.slug}
        />
      ),
    },
    {
      key: 'updated_at',
      label: i18n.t('policies.columns.updated'),
      sortable: true,
      default: true,
      render: (policy) => <RelativeTime iso={policy.updated_at} />,
    },
  ],
})
