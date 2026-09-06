import type { SavedReport } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { Badge } from '@spree/dashboard-ui'
import { ChartColumnIcon } from '@spree/dashboard-ui/icons'
import { Link } from '@tanstack/react-router'
import i18n from 'i18next'

defineTable<SavedReport>('saved-reports', {
  title: i18n.t('admin.reports.title'),
  description: i18n.t('admin.reports.subtitle'),
  searchParam: 'name_cont',
  searchPlaceholder: i18n.t('admin.reports.table.search_placeholder'),
  defaultSort: { field: 'name', direction: 'asc' },
  emptyIcon: <ChartColumnIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.reports.table.empty'),
  columns: [
    {
      key: 'name',
      label: i18n.t('admin.reports.table.columns.name'),
      sortable: true,
      default: true,
      render: (report) => (
        <Link
          to={'/$storeId/reports/$reportId' as string}
          params={{ reportId: report.id }}
          className="block no-underline"
        >
          <span className="block font-medium text-foreground">{report.name}</span>
          {report.description && (
            <span className="block text-xs text-muted-foreground">{report.description}</span>
          )}
        </Link>
      ),
    },
    {
      key: 'seeded',
      label: i18n.t('admin.reports.table.columns.kind'),
      default: true,
      render: (report) => (
        <Badge variant={report.seeded ? 'secondary' : 'outline'}>
          {i18n.t(report.seeded ? 'admin.reports.kind.built_in' : 'admin.reports.kind.custom')}
        </Badge>
      ),
    },
    {
      key: 'author_name',
      label: i18n.t('admin.reports.table.columns.author'),
      default: true,
      render: (report) => report.author_name ?? '—',
    },
  ],
})
