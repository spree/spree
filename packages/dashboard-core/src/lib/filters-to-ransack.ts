import { type ColumnDef, type FilterRule, parseFilterIds } from './table-registry'

/**
 * Convert toolbar `FilterRule[]` state into a flat Ransack predicate hash:
 *
 *   [{ field: 'name', operator: 'cont', value: 'shirt' }]
 *
 * becomes
 *
 *   { name_cont: 'shirt' }
 *
 * Columns can override the predicate target via `ransackAttribute` (e.g.
 * the `sku` column on products filters through `master_sku_cont`).
 *
 * The output shape is what both the list endpoints (after
 * `transformListParams` wraps each key in `q[...]`) and the export endpoint
 * (which stores the hash as `search_params`) expect.
 */
// Array-valued operators get a `[]` suffix so `transformListParams` emits
// `q[xxx_in][]=...` for each item. The chip stores the IDs as a CSV string
// in `FilterRule.value` so the URL serializer (which already JSON-stringifies
// FilterRule[]) stays simple.
const ARRAY_OPERATORS = new Set(['in', 'not_in'])

// Operators that mean "exclude these". A Ransack scope takes its value as an
// argument and cannot express negation, so these are dropped for scope columns
// rather than emitted as their own inverse.
const NEGATING_OPERATORS = new Set(['not_in', 'not_eq'])

export function filtersToRansack(
  filters: FilterRule[],
  columns: ColumnDef[],
): Record<string, string | string[]> {
  const out: Record<string, string | string[]> = {}
  for (const filter of filters) {
    const col = columns.find((c) => c.key === filter.field)
    // `filterType: 'tags'` rides on the polymorphic `tags` association exposed
    // via `acts_as_taggable_on`. Predicates target the join's `name` column
    // (`tags_name_in`), not the column key (`tags_in`), so default the
    // ransack alias here when one isn't explicitly set.
    const fallback = col?.filterType === 'tags' ? 'tags_name' : filter.field
    const ransackKey = col?.ransackAttribute ?? fallback
    // A Ransack *scope* is invoked by its bare name — it takes the value as
    // its argument rather than comparing a column, so appending an operator
    // suffix would name a predicate that does not exist and silently filter
    // nothing. The scope itself decides how to read the value.
    //
    // That leaves no way to express negation: emitting the same bare key for
    // `not_in` would run the scope as an inclusion and show the merchant the
    // exact opposite of what they asked for. Skip it instead, so the rule
    // visibly does nothing rather than quietly inverting.
    if (col?.ransackScope && NEGATING_OPERATORS.has(filter.operator)) continue

    const key = col?.ransackScope ? ransackKey : `${ransackKey}_${filter.operator}`
    if (ARRAY_OPERATORS.has(filter.operator)) {
      const ids = parseFilterIds(filter.value)
      if (ids.length > 0) out[key] = ids
    } else if (col?.filterType === 'date' && filter.operator === 'lteq') {
      // A date filter's upper bound is a whole day, but the columns it targets
      // are datetimes: Ransack casts `2026-08-29` to midnight, so "up to the
      // 29th" would drop everything that happened during the 29th. Carry the
      // day's last instant instead — to the microsecond, since Rails defaults
      // datetime columns to that precision and a bound of `23:59:59` would
      // drop the final second of the day. The lower bound needs no such
      // treatment: midnight is already the start of its day.
      //
      // Both ends are read in the server's zone, so a store trading far from
      // it sees the same edge-of-day skew its other date filters already have.
      // Fixing that means sending zoned bounds, which is a change to the
      // filter wire format rather than to this conversion.
      out[key] = `${filter.value} 23:59:59.999999`
    } else {
      out[key] = filter.value
    }
  }
  return out
}
