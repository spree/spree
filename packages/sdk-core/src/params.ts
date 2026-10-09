/**
 * Keys that are passed through to the API without wrapping in q[...].
 */
const PASSTHROUGH_KEYS = new Set(['page', 'limit', 'expand', 'sort', 'fields'])

type ParamValue = string | number | boolean | (string | number)[] | undefined

/**
 * Transforms flat SDK params into Ransack-compatible query params.
 *
 * - `page`, `limit`, `expand`, `sort` pass through unchanged
 * - Keys already in `q[...]` format pass through (backward compat)
 * - The entries of `q` (filters the typed params do not list) are sent like
 *   any other filter; a filter given at the top level wins over the same key in `q`
 * - All other keys are wrapped: `name_cont` → `q[name_cont]`
 */
export function transformListParams(params: object): Record<string, ParamValue> {
  const { q, ...rest } = params as { q?: Record<string, unknown> }
  const entries = [...Object.entries(q ?? {}), ...Object.entries(rest)]
  const result: Record<string, ParamValue> = {}

  for (const [key, value] of entries) {
    if (value === undefined) continue

    if (PASSTHROUGH_KEYS.has(key)) {
      // Join arrays for passthrough keys (e.g., expand: ['variants', 'media'] → 'variants,media')
      result[key] = Array.isArray(value)
        ? (value as (string | number)[]).join(',')
        : (value as ParamValue)
      continue
    }

    // Backward compat: already-wrapped q[...] keys pass through
    if (key.startsWith('q[')) {
      result[key] = value as ParamValue
      continue
    }

    // Array values get [] suffix automatically: `foo: [1,2]` → `q[foo][]`
    if (Array.isArray(value)) {
      const base = key.endsWith('[]') ? key.slice(0, -2) : key
      result[`q[${base}][]`] = value as ParamValue
    } else {
      result[`q[${key}]`] = value as ParamValue
    }
  }

  return result
}
