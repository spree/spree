import type { AllowedOrigin } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { RelativeTime, ResourceNameCell } from '@spree/dashboard-ui'
import i18n from 'i18next'
import { GlobeLockIcon } from 'lucide-react'

defineTable<AllowedOrigin>('allowed-origins', {
  title: i18n.t('admin.allowed_origins.table_title'),
  searchParam: 'origin_cont',
  searchPlaceholder: i18n.t('admin.allowed_origins.search_placeholder'),
  defaultSort: { field: 'origin', direction: 'asc' },
  emptyIcon: <GlobeLockIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.allowed_origins.empty'),
  columns: [
    {
      key: 'origin',
      label: i18n.t('admin.fields.allowed_origin.origin.label'),
      sortable: true,
      filterable: true,
      default: true,
      render: (origin) => (
        <ResourceNameCell id={origin.id} dataAttr="data-allowed-origin-id" name={origin.origin} />
      ),
    },
    {
      key: 'created_at',
      label: i18n.t('admin.fields.created_at.label'),
      sortable: true,
      default: true,
      render: (origin) => <RelativeTime iso={origin.created_at} />,
    },
  ],
})
