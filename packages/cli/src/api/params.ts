/** Query-param assembly for `spree api get` — Ransack `-q` plus passthroughs. */

export interface QueryFlags {
  query?: string[]
  sort?: string
  page?: string
  limit?: string
  expand?: string
  fields?: string
}

export type RequestParams = Record<
  string,
  string | number | boolean | (string | number)[] | undefined
>

/**
 * Turns repeatable `-q key=value` expressions into Ransack `q[...]` params and
 * passes the pagination/shaping flags through under the Admin API conventions
 * (`?sort=-created_at`, `?expand=variants`, `?fields=id,name`).
 *
 * A repeated predicate becomes an array param keyed `q[id_in][]` — the `[]`
 * suffix is required, otherwise the query serializes as `q[id_in]=a&q[id_in]=b`
 * and Rack's nested-query parser keeps only the last value (silently dropping
 * the rest).
 */
export function buildParams(flags: QueryFlags): RequestParams {
  // Collect values per predicate first, then key them with or without `[]`
  // depending on whether the predicate repeated.
  const values = new Map<string, string[]>()
  for (const expression of flags.query ?? []) {
    const eq = expression.indexOf('=')
    if (eq <= 0) {
      throw new Error(
        `Invalid -q expression "${expression}" — expected key=value (e.g. -q status_eq=active)`,
      )
    }
    const predicate = expression.slice(0, eq)
    const value = expression.slice(eq + 1)
    const existing = values.get(predicate)
    if (existing) existing.push(value)
    else values.set(predicate, [value])
  }

  const params: RequestParams = {}
  for (const [predicate, vals] of values) {
    if (vals.length > 1) {
      params[`q[${predicate}][]`] = vals
    } else {
      params[`q[${predicate}]`] = vals[0]
    }
  }

  if (flags.sort) params.sort = flags.sort
  if (flags.page !== undefined) params.page = parsePositiveInt(flags.page, '--page')
  if (flags.limit !== undefined) params.limit = parsePositiveInt(flags.limit, '--limit')
  if (flags.expand) params.expand = flags.expand
  if (flags.fields) params.fields = flags.fields

  return params
}

function parsePositiveInt(value: string, flag: string): number {
  if (!/^[1-9]\d*$/.test(value)) {
    throw new Error(`Invalid ${flag} "${value}" — expected a positive integer`)
  }
  return Number(value)
}

/**
 * Normalizes the user-supplied path: a leading slash is optional, and pasting
 * a full `/api/v3/admin/...` path (e.g. from docs or logs) just works.
 */
export function normalizePath(input: string): string {
  const path = input.startsWith('/') ? input : `/${input}`
  // Strip a pasted `/api/v3/admin` prefix, but only at a segment boundary —
  // so `/api/v3/administration` (a real resource path) is left intact.
  const prefix = '/api/v3/admin'
  if (path === prefix) return '/'
  if (path.startsWith(`${prefix}/`)) return path.slice(prefix.length)
  return path
}
