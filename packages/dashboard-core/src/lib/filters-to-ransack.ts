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
    const key = `${ransackKey}_${filter.operator}`
    if (ARRAY_OPERATORS.has(filter.operator)) {
      const ids = parseFilterIds(filter.value)
      if (ids.length > 0) out[key] = ids
    } else {
      out[key] = filter.value
    }
  }
  return out
}
