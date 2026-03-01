/**
 * Keys that are passed through to the API without wrapping in q[...].
 */
const PASSTHROUGH_KEYS = new Set(['page', 'per_page', 'includes', 'include']);

/**
 * Transforms flat SDK params into Ransack-compatible query params.
 *
 * - `page`, `per_page`, `includes`, `include` pass through unchanged
 * - `sort` maps to `q[s]`
 * - Keys already in `q[...]` format pass through (backward compat)
 * - All other keys are wrapped: `name_cont` → `q[name_cont]`
 */
export function transformListParams(
  params: Record<string, unknown>
): Record<string, string | number | undefined> {
  const result: Record<string, string | number | undefined> = {};

  for (const [key, value] of Object.entries(params)) {
    if (value === undefined) continue;

    if (PASSTHROUGH_KEYS.has(key)) {
      result[key] = value as string | number;
      continue;
    }

    if (key === 'sort') {
      result['q[s]'] = value as string;
      continue;
    }

    // Backward compat: already-wrapped q[...] keys pass through
    if (key.startsWith('q[')) {
      result[key] = value as string | number;
      continue;
    }

    result[`q[${key}]`] = value as string | number;
  }

  return result;
}
