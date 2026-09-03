import type { ReportingQuery } from '@spree/admin-sdk'
import { PageHeader } from '@spree/dashboard-core'
import { Button, ResourceLayout } from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { EMPTY_QUERY } from '../../../../components/spree/reporting/report-draft'
import { ReportWorkspace } from '../../../../components/spree/reporting/report-workspace'
import { SaveReportDialog } from '../../../../components/spree/reporting/save-report-dialog'
import { useReportRun } from '../../../../hooks/use-report-run'
import { useReportingSchema } from '../../../../hooks/use-reporting'
import { useCreateSavedReport } from '../../../../hooks/use-saved-reports'

// `?query=` carries a JSON query contract so any widget (the home screen
// cards, a future assistant) can hand its query over as a starting point.
const newReportSearchSchema = z.object({ query: z.string().optional() })

export const Route = createFileRoute('/_authenticated/$storeId/reports/new')({
  validateSearch: newReportSearchSchema,
  component: NewReportPage,
})

function seedQuery(seed: string | undefined): ReportingQuery {
  if (!seed) return EMPTY_QUERY
  try {
    const parsed = JSON.parse(seed) as ReportingQuery
    return Array.isArray(parsed.metrics) ? parsed : EMPTY_QUERY
  } catch {
    return EMPTY_QUERY
  }
}

function NewReportPage() {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const { query: seedParam } = Route.useSearch()
  const navigate = useNavigate()
  const { data: schema } = useReportingSchema()
  const [seed] = useState(() => seedQuery(seedParam))
  const [saveOpen, setSaveOpen] = useState(false)
  const create = useCreateSavedReport()
  const { draft, setDraft, query, runnable, result, error } = useReportRun(seed, schema)

  if (!schema) {
    return (
      <ResourceLayout
        header={<PageHeader title={t('admin.reports.new_title')} backTo="reports" />}
        main={<div className="text-sm text-muted-foreground">{t('admin.common.loading')}</div>}
      />
    )
  }

  return (
    <>
      <ResourceLayout
        header={
          <PageHeader
            title={t('admin.reports.new_title')}
            backTo="reports"
            actions={
              <Button onClick={() => setSaveOpen(true)} disabled={!runnable}>
                {t('admin.reports.actions.save')}
              </Button>
            }
          />
        }
        main={
          <ReportWorkspace
            draft={draft}
            onChange={setDraft}
            schema={schema}
            query={query}
            result={result}
            error={error}
          />
        }
      />
      {saveOpen && (
        <SaveReportDialog
          open
          onOpenChange={setSaveOpen}
          title={t('admin.reports.save_dialog.title_create')}
          submitLabel={t('admin.reports.actions.save')}
          onSubmit={async (values) => {
            const report = await create.mutateAsync({ ...values, query })
            navigate({
              to: '/$storeId/reports/$reportId',
              params: { storeId, reportId: report.id },
            })
          }}
        />
      )}
    </>
  )
}
