// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type ReportingQueryParams = {
  /** Registered metric names, from the reporting schema endpoint. */
  metrics: string[]
  /**
   * Up to 2 dimensions to break the metrics down by. Each is a dimension name, or
   * `{ name, grain, include_empty }`: `grain` (`hour`, `day`, `week`, `month`) buckets a time
   * dimension, and `include_empty` lists members with no matching rows where the schema entry
   * supports it.
   */
  dimensions?: unknown[]
  /** Narrows the rows by dimension value. */
  filters?: {
    dimension: string
    op: 'eq' | 'in'
    /** One value for `eq`, a list for `in`. */
    value: unknown
  }[]
  /**
   * Filters on an aggregate, such as `units_sold = 0`. Narrows the rows only; the totals stay the
   * period's real figure. The metric must also appear in `metrics`, and cannot be a derived one.
   */
  metric_filters?: {
    metric: string
    op: 'eq' | 'gt' | 'gte' | 'lt' | 'lte'
    value: number
  }[]
  /**
   * A named preset (`last_month`, `week_to_date`, any `last_<n>_<days|weeks|months>`), or ISO 8601
   * dates or times in `since` and `until` (a bare date covers the store's whole day). Defaults to
   * the last 30 days, in the store's time zone.
   */
  time_range?: {
    preset?: string
    since?: string
    until?: string
  }
  compare?: 'previous_period' | 'previous_year'
  /** A metric name; prefix it with `-` to sort descending. */
  sort?: string
  /** At most 1000. */
  limit?: number
  currency?: string
}
