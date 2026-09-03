import type {
  ReportingGrain,
  ReportingQuery,
  ReportingSchema,
  ReportingSchemaDimension,
} from '@spree/admin-sdk'

export const DEFAULT_PRESET = 'last_4_weeks'
// Used only until the schema (which publishes the server's real limits) has loaded.
const FALLBACK_LIMIT = 50

export type ReportTimeRange = { preset: string } | { since: string; until: string }

export interface ReportFilter {
  dimension: string
  values: string[]
}

/**
 * The builder's editable state. It is a UI-shaped projection of the query
 * contract (one dimension, one sort metric, filters as value lists) — the
 * contract itself stays the only thing the API sees and the only thing a
 * saved report stores.
 */
export interface ReportDraft {
  metrics: string[]
  dimension: string | null
  grain: ReportingGrain
  timeRange: ReportTimeRange
  filters: ReportFilter[]
  compare: boolean
  sortMetric: string | null
  sortDirection: 'asc' | 'desc'
  limit: number
}

type ReportViz = 'chart' | 'ranking' | 'stats'

/** What a brand-new report starts from: revenue and orders per day, compared. */
export const EMPTY_QUERY: ReportingQuery = {
  metrics: ['gross_revenue', 'orders_count'],
  dimensions: [{ name: 'completed_at', grain: 'day' }],
  time_range: { preset: DEFAULT_PRESET },
  compare: 'previous_period',
}

export function findDimension(
  schema: ReportingSchema | undefined,
  name: string | null | undefined,
): ReportingSchemaDimension | undefined {
  return name ? schema?.dimensions.find((d) => d.name === name) : undefined
}

export function isTimeDimension(dimension: ReportingSchemaDimension | undefined): boolean {
  return dimension?.type === 'time'
}

export function queryDimension(
  query: ReportingQuery,
): { name: string; grain?: ReportingGrain } | null {
  const first = query.dimensions?.[0]
  if (!first) return null
  return typeof first === 'string' ? { name: first } : first
}

export function draftFromQuery(query: ReportingQuery, schema?: ReportingSchema): ReportDraft {
  const dimension = queryDimension(query)
  const sort = query.sort ?? null
  const range = query.time_range
  // Same precedence as the server: a named preset wins over since/until.
  const timeRange: ReportTimeRange = range?.preset
    ? { preset: range.preset }
    : range?.since && range?.until
      ? { since: range.since, until: range.until }
      : { preset: DEFAULT_PRESET }

  return {
    metrics: [...query.metrics],
    dimension: dimension?.name ?? null,
    grain: dimension?.grain ?? 'day',
    timeRange,
    filters: (query.filters ?? []).map((filter) => ({
      dimension: filter.dimension,
      values: Array.isArray(filter.value) ? filter.value : [filter.value],
    })),
    compare: query.compare === 'previous_period',
    sortMetric: sort ? sort.replace(/^-/, '') : null,
    sortDirection: sort && !sort.startsWith('-') ? 'asc' : 'desc',
    limit: query.limit ?? schema?.limits.default ?? FALLBACK_LIMIT,
  }
}

export function queryFromDraft(draft: ReportDraft, schema?: ReportingSchema): ReportingQuery {
  const dimension = findDimension(schema, draft.dimension)
  const timeDimension = isTimeDimension(dimension)
  const query: ReportingQuery = { metrics: draft.metrics, time_range: { ...draft.timeRange } }

  if (draft.dimension) {
    query.dimensions = timeDimension
      ? [{ name: draft.dimension, grain: draft.grain }]
      : [draft.dimension]
  }

  const filters = draft.filters
    .filter((filter) => filter.values.length > 0)
    .map((filter) =>
      filter.values.length === 1
        ? { dimension: filter.dimension, op: 'eq' as const, value: filter.values[0] }
        : { dimension: filter.dimension, op: 'in' as const, value: filter.values },
    )
  if (filters.length > 0) query.filters = filters
  if (draft.compare) query.compare = 'previous_period'

  // Sort and limit only mean something for a ranking; a time series is
  // always complete and chronological.
  if (draft.dimension && !timeDimension) {
    const sortMetric =
      draft.sortMetric && draft.metrics.includes(draft.sortMetric)
        ? draft.sortMetric
        : draft.metrics[0]
    if (sortMetric) query.sort = `${draft.sortDirection === 'desc' ? '-' : ''}${sortMetric}`
    query.limit = draft.limit
  }

  return query
}

/**
 * Picks the visualization from the query's shape: a time dimension is a
 * chart, any other dimension a ranked table, no dimension a row of totals.
 * Without a schema (a saved report referencing a dimension the viewer cannot
 * read) the grain the query carries is the time hint.
 */
export function inferViz(query: ReportingQuery, schema?: ReportingSchema): ReportViz {
  const dimension = queryDimension(query)
  if (!dimension) return 'stats'
  const definition = findDimension(schema, dimension.name)
  const time = definition ? isTimeDimension(definition) : !!dimension.grain
  return time ? 'chart' : 'ranking'
}
