import type { ColumnDef, FilterRule } from '@/lib/table-registry'

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
export function filtersToRansack(
  filters: FilterRule[],
  columns: ColumnDef[],
): Record<string, string> {
  const out: Record<string, string> = {}
  for (const filter of filters) {
    const col = columns.find((c) => c.key === filter.field)
    const ransackKey = col?.ransackAttribute ?? filter.field
    out[`${ransackKey}_${filter.operator}`] = filter.value
  }
  return out
}
