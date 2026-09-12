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
  metrics: ['total_sales', 'orders'],
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

/**
 * Whether an hourly series over this range fits inside the server's bucket
 * ceiling. A custom range is measured; a preset is matched against the day
 * count in its own name, since the server's preset vocabulary is wider than
 * the client's date helper knows. Anything unrecognised counts as too wide, so
 * the grain is withheld rather than offered and then refused.
 */
export function hourGrainFitsRange(timeRange: ReportTimeRange, maxBuckets: number): boolean {
  if ('since' in timeRange) {
    const hours = (Date.parse(timeRange.until) - Date.parse(timeRange.since)) / 3_600_000 + 24
    return hours <= maxBuckets
  }
  const preset = timeRange.preset
  if (preset === 'today' || preset === 'yesterday') return true
  // The server's relative grammar is `last_<n>_<days|weeks|months>`; each unit
  // is converted at its longest so the estimate never claims a range fits when
  // the server would refuse it.
  const relative = preset.match(/^last_(\d+)_(days|weeks|months)$/)
  if (relative) {
    const perUnit = { days: 1, weeks: 7, months: 31 }[relative[2] as 'days' | 'weeks' | 'months']
    return (Number(relative[1]) * perUnit + 1) * 24 <= maxBuckets
  }
  // Named presets bounded by a month or less; a quarter is 2,208 hours, over
  // the ceiling, so it and everything longer fall through to false.
  return ['week_to_date', 'last_week', 'month_to_date', 'last_month'].includes(preset)
}

/**
 * The draft's grain, stepped down when it is no longer servable — because the
 * dimension stopped offering it, or because the range grew too wide to chart
 * hourly. A saved report carrying a stale hourly grain would otherwise fire a
 * query the server refuses, with nothing in the picker the merchant could
 * change to clear it.
 */
export function servableGrain(
  draft: ReportDraft,
  dimension: ReportingSchemaDimension | undefined,
  maxBuckets: number,
): ReportingGrain {
  if (!dimension?.grains?.includes(draft.grain)) return 'day'
  if (draft.grain === 'hour' && !hourGrainFitsRange(draft.timeRange, maxBuckets)) return 'day'
  return draft.grain
}

function maxBuckets(schema?: ReportingSchema): number {
  return schema?.limits?.max_buckets ?? 2000
}

export function queryFromDraft(draft: ReportDraft, schema?: ReportingSchema): ReportingQuery {
  const dimension = findDimension(schema, draft.dimension)
  const timeDimension = isTimeDimension(dimension)
  const query: ReportingQuery = { metrics: draft.metrics, time_range: { ...draft.timeRange } }

  if (draft.dimension) {
    query.dimensions = timeDimension
      ? [{ name: draft.dimension, grain: servableGrain(draft, dimension, maxBuckets(schema)) }]
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
