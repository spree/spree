import type { Diagnostics } from '@spree/admin-sdk'
import {
  PageHeader,
  Subject,
  useOptionalDeveloperInspector,
  usePermissions,
} from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  CopyToClipboardButton,
  Empty,
  Skeleton,
} from '@spree/dashboard-ui'
import { BugIcon } from '@spree/dashboard-ui/icons'
import { createFileRoute } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import { useDiagnostics } from '../../../../hooks/use-diagnostics'

export const Route = createFileRoute('/_authenticated/$storeId/settings/system-info')({
  component: SystemInfoRoute,
})

function SystemInfoRoute() {
  const { t } = useTranslation()
  const { permissions } = usePermissions()
  const allowed = permissions.can('manage', Subject.Store)
  const { data: report, isLoading, isError } = useDiagnostics()

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title={t('admin.system_info.title')}
        actions={report && <ReportActions report={report} />}
      />
      {!allowed ? (
        <Empty>{t('admin.system_info.unavailable')}</Empty>
      ) : isLoading ? (
        <Skeleton className="h-96 w-full" />
      ) : isError || !report ? (
        <Empty>{t('admin.system_info.load_failed')}</Empty>
      ) : (
        <SystemInfo report={report} />
      )}
    </div>
  )
}

function ReportActions({ report }: { report: Diagnostics }) {
  const { t } = useTranslation()
  const sendFeedback = useOptionalDeveloperInspector()?.sendFeedback

  return (
    <>
      <CopyToClipboardButton
        value={report.markdown}
        size="default"
        variant="outline"
        aria-label={t('admin.system_info.copy')}
        label={t('admin.system_info.copy')}
        copiedLabel={t('admin.system_info.copied')}
      />
      {sendFeedback && (
        <Button variant="outline" onClick={() => sendFeedback('bug')}>
          <BugIcon />
          {t('admin.system_info.report_issue')}
        </Button>
      )}
    </>
  )
}

// The page shows what a maintainer asks for first; the copied report and the
// GitHub issue also carry the browser and the recent errors.
const HIDDEN_SECTIONS = ['client']
const HIDDEN_ROWS = ['Other gems built on Spree']
// The dashboard's own packages sit beside Spree's gems, where versions are read.
const SECTION_ORDER = ['platform', 'dashboard']

function SystemInfo({ report }: { report: Diagnostics }) {
  const sections = report.sections
    .filter((section) => !HIDDEN_SECTIONS.includes(section.key))
    .map((section) => ({
      ...section,
      rows: section.rows.filter((row) => !HIDDEN_ROWS.includes(row.label)),
    }))
    .filter((section) => section.rows.length > 0)
    .sort((a, b) => rank(a.key) - rank(b.key))

  return (
    <div className="grid gap-4 lg:grid-cols-2">
      {sections.map((section) => (
        <Card key={section.key}>
          <CardHeader>
            <CardTitle>{section.title}</CardTitle>
          </CardHeader>
          <CardContent>
            <dl className="grid grid-cols-[max-content_minmax(0,1fr)] gap-x-4 gap-y-2 text-sm">
              {section.rows.map((row) => (
                <div key={row.label} className="contents">
                  <dt className="text-muted-foreground">{row.label}</dt>
                  <dd className="break-words font-mono">{row.value}</dd>
                </div>
              ))}
            </dl>
          </CardContent>
        </Card>
      ))}
    </div>
  )
}

function rank(key: string): number {
  const index = SECTION_ORDER.indexOf(key)
  return index === -1 ? SECTION_ORDER.length : index
}
