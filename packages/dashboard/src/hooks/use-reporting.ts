import type { ReportingQuery, ReportingResult } from '@spree/admin-sdk'
import { adminClient } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'

/**
 * Runs a semantic reporting query (`POST /reporting/query`). The query object
 * itself is the cache key, so callers just describe what they want; identical
 * queries share one request. Results stay fresh for 5 minutes and the
 * previous result is kept while a changed query refetches (no flicker when
 * the merchant moves the date range or channel).
 */
export function useReportingQuery(query: ReportingQuery, options: { enabled?: boolean } = {}) {
  return useQuery<ReportingResult>({
    queryKey: ['reporting', 'query', query],
    queryFn: () => adminClient.reporting.query(query),
    staleTime: 5 * 60 * 1000,
    placeholderData: (previousData) => previousData,
    enabled: options.enabled ?? true,
  })
}
