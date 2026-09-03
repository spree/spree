import type { ReportingQuery, ReportingSchema } from '@spree/admin-sdk'
import { useMemo, useState } from 'react'
import {
  draftFromQuery,
  queryFromDraft,
  type ReportDraft,
} from '../components/spree/reporting/report-draft'
import { useReportingQuery } from './use-reporting'

/**
 * The builder loop shared by the new-report and saved-report pages: editable
 * draft → contract query → live result. Placeholder data is the previous
 * query's result, a different shape while the builder changes, so the view
 * gets `undefined` until the real rows arrive.
 */
export function useReportRun(
  initialQuery: ReportingQuery | null,
  schema: ReportingSchema | undefined,
) {
  const [draft, setDraft] = useState<ReportDraft>(() =>
    draftFromQuery(initialQuery ?? { metrics: [] }, schema),
  )
  const query = useMemo(() => queryFromDraft(draft, schema), [draft, schema])
  const runnable = !!schema && draft.metrics.length > 0
  const { data, error, isPlaceholderData } = useReportingQuery(query, { enabled: runnable })

  // The saved query round-trips through the draft so formatting differences
  // (grain defaults, filter op normalization) never count as edits.
  const baseline = useMemo(
    () =>
      initialQuery ? JSON.stringify(queryFromDraft(draftFromQuery(initialQuery), schema)) : null,
    [initialQuery, schema],
  )
  const dirty = baseline !== null && JSON.stringify(query) !== baseline

  return {
    draft,
    setDraft,
    query,
    runnable,
    dirty,
    result: runnable && !isPlaceholderData ? data : undefined,
    error,
  }
}
