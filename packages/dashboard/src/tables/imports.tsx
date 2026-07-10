import type { Import } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { RelativeTime, ResourceNameCell, StatusBadge } from '@spree/dashboard-ui'
import i18n from 'i18next'
import { UploadIcon } from 'lucide-react'
import { importTypeLabel } from '@/lib/import-types'

defineTable<Import>('imports', {
  title: i18n.t('admin.pages.settings.imports.title'),
  searchParam: 'number_cont',
  searchPlaceholder: i18n.t('admin.pages.settings.imports.search_placeholder'),
  defaultSort: { field: 'created_at', direction: 'desc' },
  emptyIcon: <UploadIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.pages.settings.imports.empty_title'),
  columns: [
    {
      key: 'number',
      label: i18n.t('admin.pages.settings.imports.table.number'),
      sortable: true,
      filterable: true,
      default: true,
      render: (imp) => <ResourceNameCell id={imp.id} dataAttr="data-import-id" name={imp.number} />,
    },
    {
      key: 'type',
      label: i18n.t('admin.pages.settings.imports.table.type'),
      sortable: true,
      default: true,
      render: (imp) => importTypeLabel(imp.type),
    },
    {
      key: 'status',
      label: i18n.t('admin.pages.settings.imports.table.status'),
      sortable: true,
      filterable: true,
      default: true,
      render: (imp) => (
        <StatusBadge status={imp.status} label={i18n.t(`admin.imports.status.${imp.status}`)} />
      ),
    },
    {
      key: 'rows',
      label: i18n.t('admin.pages.settings.imports.table.rows'),
      default: true,
      render: (imp) => {
        if (imp.rows_count === 0) return <span className="text-muted-foreground">—</span>
        return (
          <span>
            {imp.completed_rows_count}/{imp.rows_count}
            {imp.failed_rows_count > 0 && (
              <span className="ml-1 text-destructive">
                ·{' '}
                {i18n.t('admin.pages.settings.imports.table.failed_count', {
                  failed: imp.failed_rows_count,
                })}
              </span>
            )}
          </span>
        )
      },
    },
    {
      key: 'created_at',
      label: i18n.t('admin.fields.created_at.label'),
      sortable: true,
      default: true,
      render: (imp) => <RelativeTime iso={imp.created_at} />,
    },
  ],
})
