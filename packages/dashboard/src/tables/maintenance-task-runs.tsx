import type { MaintenanceTaskRun } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { RelativeTime, ResourceNameCell, StatusBadge } from '@spree/dashboard-ui'
import i18n from 'i18next'
import { HistoryIcon } from 'lucide-react'
import { taskShortName } from '../lib/maintenance-tasks'

defineTable<MaintenanceTaskRun>('maintenance-task-runs', {
  title: i18n.t('admin.maintenance_tasks.history.title'),
  searchParam: 'task_name_cont',
  searchPlaceholder: i18n.t('admin.maintenance_tasks.history.search_placeholder'),
  defaultSort: { field: 'created_at', direction: 'desc' },
  emptyIcon: <HistoryIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.maintenance_tasks.history.empty_title'),
  columns: [
    {
      key: 'task_name',
      label: i18n.t('admin.maintenance_tasks.history.table.task'),
      sortable: true,
      filterable: true,
      default: true,
      render: (run) => (
        <ResourceNameCell
          id={run.id}
          dataAttr="data-maintenance-task-run-id"
          name={taskShortName(run.task_name)}
        />
      ),
    },
    {
      key: 'status',
      label: i18n.t('admin.maintenance_tasks.history.table.status'),
      sortable: true,
      filterable: true,
      default: true,
      render: (run) => (
        <div className="flex items-center gap-2">
          <StatusBadge
            status={run.status}
            label={i18n.t(`admin.maintenance_tasks.status.${run.status}`)}
          />
          {run.dry_run && (
            <span className="text-muted-foreground text-xs">
              {i18n.t('admin.maintenance_tasks.dry_run_badge')}
            </span>
          )}
        </div>
      ),
    },
    {
      key: 'progress',
      label: i18n.t('admin.maintenance_tasks.history.table.processed'),
      default: true,
      // A task that could not count its collection reports ticks alone —
      // showing "12 / null" would read as a bug rather than an unknown total.
      render: (run) =>
        run.tick_total == null ? (
          <span>{run.tick_count}</span>
        ) : (
          <span>
            {run.tick_count} / {run.tick_total}
          </span>
        ),
    },
    {
      key: 'initiated_by',
      label: i18n.t('admin.maintenance_tasks.history.table.initiated_by'),
      default: true,
      render: (run) =>
        run.admin_user ? (
          <span>{run.admin_user.email}</span>
        ) : (
          <span className="text-muted-foreground">
            {i18n.t(`admin.maintenance_tasks.initiated_via.${run.initiated_via}`)}
          </span>
        ),
    },
    {
      key: 'created_at',
      label: i18n.t('admin.fields.created_at.label'),
      sortable: true,
      default: true,
      render: (run) => <RelativeTime iso={run.created_at} />,
    },
  ],
})
