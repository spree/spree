import type { SavedReport } from '@spree/admin-sdk'
import {
  adminClient,
  ResourceTable,
  resourceSearchSchema,
  Subject,
  usePermissions,
} from '@spree/dashboard-core'
import { Button, RowActions, useConfirm } from '@spree/dashboard-ui'
import { PlusIcon } from '@spree/dashboard-ui/icons'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import { useDeleteSavedReport } from '../../../../hooks/use-saved-reports'
import '../../../../tables/saved-reports'

export const Route = createFileRoute('/_authenticated/$storeId/reports/')({
  validateSearch: resourceSearchSchema,
  component: ReportsPage,
})

function ReportsPage() {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const searchParams = Route.useSearch()
  const navigate = useNavigate()
  const { permissions } = usePermissions()

  return (
    <ResourceTable<SavedReport>
      tableKey="saved-reports"
      queryKey="saved-reports"
      queryFn={(params) => adminClient.reporting.savedReports.list(params)}
      searchParams={searchParams}
      rowActions={(report) => <ReportRowActions report={report} storeId={storeId} />}
      actions={
        permissions.can('create', Subject.SavedReport) ? (
          <Button
            size="sm"
            className="h-[2.125rem]"
            onClick={() => navigate({ to: '/$storeId/reports/new', params: { storeId } })}
          >
            <PlusIcon className="size-4" />
            {t('admin.reports.new_cta')}
          </Button>
        ) : null
      }
    />
  )
}

function ReportRowActions({ report, storeId }: { report: SavedReport; storeId: string }) {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const confirm = useConfirm()
  const deleteMutation = useDeleteSavedReport()
  const { permissions } = usePermissions()

  async function handleDelete() {
    const ok = await confirm({
      title: t('admin.actions.delete'),
      message: t('admin.reports.delete_confirm', { name: report.name }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(report.id).catch(() => undefined)
  }

  return (
    <RowActions
      actions={[
        {
          key: 'edit',
          onSelect: () =>
            navigate({
              to: '/$storeId/reports/$reportId',
              params: { storeId, reportId: report.id },
            }),
        },
        {
          key: 'delete',
          destructive: true,
          visible: permissions.can('destroy', Subject.SavedReport),
          disabled: deleteMutation.isPending,
          onSelect: handleDelete,
        },
      ]}
    />
  )
}
