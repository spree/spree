import type { Promotion } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { Badge, RelativeTime, ResourceNameCell } from '@spree/dashboard-ui'
import i18n from 'i18next'
import { TagIcon } from 'lucide-react'

defineTable<Promotion>('promotions', {
  title: i18n.t('admin.nav.promotions'),
  searchParam: 'name_cont',
  searchPlaceholder: i18n.t('admin.promotions.table.search_placeholder'),
  defaultSort: { field: 'created_at', direction: 'desc' },
  emptyIcon: <TagIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.promotions.table.empty'),
  columns: [
    {
      key: 'name',
      label: i18n.t('admin.fields.name.label'),
      sortable: true,
      filterable: true,
      default: true,
      render: (p) => (
        <ResourceNameCell
          id={p.id}
          dataAttr="data-promotion-id"
          name={p.name}
          secondary={p.description}
        />
      ),
    },
    {
      key: 'code',
      label: i18n.t('admin.fields.code.label'),
      sortable: true,
      filterable: true,
      default: true,
      render: (p) => {
        if (p.kind === 'automatic')
          return <Badge variant="outline">{i18n.t('admin.promotions.code.automatic')}</Badge>
        if (p.multi_codes)
          return (
            <Badge variant="outline">
              {p.code_prefix ?? i18n.t('admin.promotions.code.multi')}…
            </Badge>
          )
        return p.code ? <code className="text-xs">{p.code}</code> : '—'
      },
    },
    {
      key: 'starts_at',
      label: i18n.t('admin.fields.starts_at.label'),
      sortable: true,
      filterType: 'date',
      default: true,
      className: 'text-sm text-muted-foreground whitespace-nowrap',
      render: (p) => (p.starts_at ? <RelativeTime iso={p.starts_at} /> : '—'),
    },
    {
      key: 'expires_at',
      label: i18n.t('admin.fields.expires_at.label'),
      sortable: true,
      filterType: 'date',
      default: true,
      className: 'text-sm text-muted-foreground whitespace-nowrap',
      render: (p) => {
        if (!p.expires_at)
          return (
            <span className="text-muted-foreground">{i18n.t('admin.promotions.table.no_end')}</span>
          )
        const expired = new Date(p.expires_at) < new Date()
        return (
          <span className={expired ? 'text-destructive' : undefined}>
            <RelativeTime iso={p.expires_at} />
          </span>
        )
      },
    },
  ],
})
