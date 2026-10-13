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
 * - The entries of `q` (filters the typed params do not list) are always sent
 *   inside `q`, even one named `page` or `sort`; a filter given at the top
 *   level wins over the same key in `q`
 * - Nested objects are sent in bracket form: `{ g: { a: 1 } }` → `q[g][a]`
 * - All other keys are wrapped: `name_cont` → `q[name_cont]`
 */
export function transformListParams(params: object): Record<string, ParamValue> {
  const { q, ...rest } = params as { q?: Record<string, unknown> }
  const result: Record<string, ParamValue> = {}

  for (const [key, value] of Object.entries(q ?? {})) {
    appendFilter(result, key, value)
  }

  for (const [key, value] of Object.entries(rest)) {
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

    appendFilter(result, key, value)
  }

  return result
}

// Writes `foo: [1, 2]` as `q[foo][]` and `g: { a: 1 }` as `q[g][a]`, the
// bracket nesting Rails parses back into the `q` hash.
function appendFilter(
  result: Record<string, ParamValue>,
  key: string,
  value: unknown,
  prefix = 'q',
) {
  if (value === undefined) return

  const name = `${prefix}[${key.endsWith('[]') ? key.slice(0, -2) : key}]`

  if (Array.isArray(value)) {
    result[`${name}[]`] = value as ParamValue
  } else if (value !== null && typeof value === 'object') {
    for (const [nestedKey, nestedValue] of Object.entries(value)) {
      appendFilter(result, nestedKey, nestedValue, name)
    }
  } else {
    result[name] = value as ParamValue
  }
}
