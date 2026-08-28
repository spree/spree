import type { Policy } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { RelativeTime, ResourceNameCell } from '@spree/dashboard-ui'
import i18n from 'i18next'
import { ScrollTextIcon } from 'lucide-react'

defineTable<Policy>('policies', {
  title: i18n.t('admin.settings_nav.items.policies'),
  searchParam: 'name_cont',
  searchPlaceholder: i18n.t('admin.policies.search_placeholder'),
  defaultSort: { field: 'name', direction: 'asc' },
  emptyIcon: <ScrollTextIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.policies.empty'),
  columns: [
    {
      key: 'name',
      label: i18n.t('admin.fields.name.label'),
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
      key: 'body',
      label: i18n.t('admin.fields.policy.body.label'),
      default: true,
      // Whether anything has actually been written: a store ships with the
      // four standard policies named but empty, and an empty legal page is
      // the thing a merchant most needs to spot.
      render: (policy) =>
        policy.body?.trim() ? (
          <span className="line-clamp-1 text-muted-foreground">{policy.body}</span>
        ) : (
          <span className="text-muted-foreground">{i18n.t('admin.policies.no_content')}</span>
        ),
    },
    {
      key: 'updated_at',
      label: i18n.t('admin.fields.updated_at.label'),
      sortable: true,
      default: true,
      render: (policy) => <RelativeTime iso={policy.updated_at} />,
    },
  ],
})
