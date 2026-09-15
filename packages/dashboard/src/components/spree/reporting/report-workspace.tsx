import type { ReportingQuery, ReportingResult, ReportingSchema } from '@spree/admin-sdk'
import { ReportBuilder } from './report-builder'
import type { ReportDraft } from './report-draft'
import { ReportView } from './report-view'

interface ReportWorkspaceProps {
  draft: ReportDraft
  onChange: (draft: ReportDraft) => void
  schema: ReportingSchema
  query: ReportingQuery
  result: ReportingResult | undefined
  error?: Error | null
}

/** Builder beside a live preview — the layout both the new and the saved report pages share. */
export function ReportWorkspace({
  draft,
  onChange,
  schema,
  query,
  result,
  error,
}: ReportWorkspaceProps) {
  return (
    <div className="grid items-start gap-6 lg:grid-cols-[20rem_minmax(0,1fr)]">
      <ReportBuilder draft={draft} onChange={onChange} schema={schema} />
      <ReportView query={query} schema={schema} result={result} error={error} />
    </div>
  )
}
