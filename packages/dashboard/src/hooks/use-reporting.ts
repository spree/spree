import type {
  ReportingDimensionValue,
  ReportingQuery,
  ReportingResult,
  ReportingRow,
  ReportingSchema,
} from '@spree/admin-sdk'
import { adminClient, useResourceKey } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'

/**
 * Runs a semantic reporting query (`POST /reporting/query`). The query object
 * itself is part of the store-scoped cache key, so callers just describe what
 * they want; identical queries share one request. Results stay fresh for 5
 * minutes and the previous result is kept while a changed query refetches (no
 * flicker when the merchant moves the date range or channel).
 */
export function useReportingQuery(query: ReportingQuery, options: { enabled?: boolean } = {}) {
  return useQuery<ReportingResult>({
    queryKey: useResourceKey('reporting', 'query', query),
    queryFn: () => adminClient.reporting.query(query),
    staleTime: 5 * 60 * 1000,
    placeholderData: (previousData) => previousData,
    enabled: options.enabled ?? true,
  })
}

/**
 * Narrows a row's dimension value to the hydrated display payload of a
 * lookup-backed dimension. The runtime check replaces per-call-site casts.
 */
export function entityDimension(row: ReportingRow, name: string): ReportingDimensionValue {
  const value = row.dimensions[name]
  if (value === undefined) return { id: null, label: '', meta: {} }
  return typeof value === 'string' ? { id: null, label: value, meta: {} } : value
}

/** Narrows a row's dimension value to a raw bucket/status string. */
export function rawDimension(row: ReportingRow, name: string): string {
  const value = row.dimensions[name]
  if (value === undefined) return ''
  return typeof value === 'string' ? value : value.label
}

/** Reads a string field out of a hydrated dimension's `meta`, if present. */
export function metaString(dimension: ReportingDimensionValue, key: string): string | undefined {
  const value = dimension.meta?.[key]
  return typeof value === 'string' ? value : undefined
}

/**
 * The permission-filtered reporting vocabulary (`GET /reporting/schema`):
 * metrics, dimensions (with compatible metrics, filter ops and enumerated
 * values) and time-range presets. Drives the report builder so the UI never
 * hardcodes what the server can compute.
 */
export function useReportingSchema() {
  return useQuery<ReportingSchema>({
    queryKey: useResourceKey('reporting', 'schema'),
    queryFn: () => adminClient.reporting.schema(),
    staleTime: 30 * 60 * 1000,
  })
}
