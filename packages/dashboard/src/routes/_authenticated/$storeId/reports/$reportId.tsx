import type { ReportingQuery, ReportingSchema, SavedReport } from '@spree/admin-sdk'
import { PageHeader, Subject, useExport, usePermissions } from '@spree/dashboard-core'
import { Badge, Button, DropdownMenuItem, ResourceLayout, useConfirm } from '@spree/dashboard-ui'
import { DownloadIcon } from '@spree/dashboard-ui/icons'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { ReportWorkspace } from '../../../../components/spree/reporting/report-workspace'
import { SaveReportDialog } from '../../../../components/spree/reporting/save-report-dialog'
import { useReportRun } from '../../../../hooks/use-report-run'
import { useReportingSchema } from '../../../../hooks/use-reporting'
import {
  useCreateSavedReport,
  useDeleteSavedReport,
  useSavedReport,
  useUpdateSavedReport,
} from '../../../../hooks/use-saved-reports'

export const Route = createFileRoute('/_authenticated/$storeId/reports/$reportId')({
  component: ReportPage,
})

const EXPORT_TYPE = 'Spree::Exports::Report'

function ReportPage() {
  const { t } = useTranslation()
  const { storeId, reportId } = Route.useParams()
  const { data: report } = useSavedReport(reportId)
  const { data: schema } = useReportingSchema()

  if (!report || !schema) {
    return (
      <ResourceLayout
        header={<PageHeader title={t('admin.common.loading')} backTo="reports" />}
        main={<div className="text-sm text-muted-foreground">{t('admin.common.loading')}</div>}
      />
    )
  }

  // Keyed by id so navigating between reports re-seeds the draft from the
  // freshly loaded record instead of syncing state in an effect.
  return <ReportDetail key={report.id} report={report} schema={schema} storeId={storeId} />
}

function ReportDetail({
  report,
  schema,
  storeId,
}: {
  report: SavedReport
  schema: ReportingSchema
  storeId: string
}) {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const confirm = useConfirm()
  const { permissions } = usePermissions()
  const savedQuery = report.query as unknown as ReportingQuery
  const [dialog, setDialog] = useState<'copy' | 'rename' | null>(null)
  const { draft, setDraft, query, runnable, dirty, result, error } = useReportRun(
    savedQuery,
    schema,
  )

  const update = useUpdateSavedReport(report.id)
  const create = useCreateSavedReport()
  const remove = useDeleteSavedReport()
  const exportMutation = useExport()

  const canCreate = permissions.can('create', Subject.SavedReport)
  const canExport = permissions.can('create', Subject.ReportExport)
  const canUpdate = !report.seeded && permissions.can('update', Subject.SavedReport)
  const canDestroy = permissions.can('destroy', Subject.SavedReport)

  async function handleDelete() {
    const ok = await confirm({
      title: t('admin.actions.delete'),
      message: t('admin.reports.delete_confirm', { name: report.name }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await remove.mutateAsync(report.id)
    navigate({ to: '/$storeId/reports', params: { storeId } })
  }

  return (
    <>
      <ResourceLayout
        header={
          <PageHeader
            title={report.name}
            subtitle={report.description ?? undefined}
            backTo="reports"
            badges={
              report.seeded && <Badge variant="secondary">{t('admin.reports.kind.built_in')}</Badge>
            }
            actions={
              <>
                {canExport && (
                  <Button
                    variant="outline"
                    disabled={!runnable || exportMutation.isPending}
                    onClick={() =>
                      exportMutation.mutate({ type: EXPORT_TYPE, search_params: { query } })
                    }
                  >
                    <DownloadIcon className="size-4" />
                    {t('admin.reports.actions.export_csv')}
                  </Button>
                )}
                {canUpdate && (
                  <Button
                    disabled={!dirty || !runnable || update.isPending}
                    onClick={() => update.mutate({ query })}
                  >
                    {t('admin.reports.actions.save')}
                  </Button>
                )}
                {report.seeded && canCreate && (
                  <Button disabled={!runnable} onClick={() => setDialog('copy')}>
                    {t('admin.reports.actions.save_copy')}
                  </Button>
                )}
              </>
            }
            dropdownItems={
              <>
                {canUpdate && (
                  <DropdownMenuItem onClick={() => setDialog('rename')}>
                    {t('admin.reports.actions.rename')}
                  </DropdownMenuItem>
                )}
                {!report.seeded && canCreate && (
                  <DropdownMenuItem disabled={!runnable} onClick={() => setDialog('copy')}>
                    {t('admin.reports.actions.save_copy')}
                  </DropdownMenuItem>
                )}
              </>
            }
            destructiveItems={
              canDestroy ? (
                <DropdownMenuItem
                  variant="destructive"
                  disabled={remove.isPending}
                  onClick={handleDelete}
                >
                  {t('admin.actions.delete')}
                </DropdownMenuItem>
              ) : undefined
            }
          />
        }
        main={
          <div className="flex flex-col gap-4">
            {report.seeded && (
              <p className="text-sm text-muted-foreground">{t('admin.reports.seeded_hint')}</p>
            )}
            <ReportWorkspace
              draft={draft}
              onChange={setDraft}
              schema={schema}
              query={query}
              result={result}
              error={error}
            />
          </div>
        }
      />
      {dialog === 'rename' && (
        <SaveReportDialog
          open
          onOpenChange={(open) => !open && setDialog(null)}
          title={t('admin.reports.save_dialog.title_rename')}
          submitLabel={t('admin.reports.actions.save')}
          defaultValues={{ name: report.name, description: report.description ?? '' }}
          onSubmit={(values) => update.mutateAsync(values)}
        />
      )}
      {dialog === 'copy' && (
        <SaveReportDialog
          open
          onOpenChange={(open) => !open && setDialog(null)}
          title={t('admin.reports.save_dialog.title_copy')}
          submitLabel={t('admin.reports.actions.save')}
          defaultValues={{
            name: t('admin.reports.copy_name', { name: report.name }),
            description: report.description ?? '',
          }}
          onSubmit={async (values) => {
            const copy = await create.mutateAsync({ ...values, query })
            navigate({ to: '/$storeId/reports/$reportId', params: { storeId, reportId: copy.id } })
          }}
        />
      )}
    </>
  )
}
