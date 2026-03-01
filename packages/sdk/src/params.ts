/**
 * Keys that are passed through to the API without wrapping in q[...].
 */
const PASSTHROUGH_KEYS = new Set(['page', 'per_page', 'includes', 'include', 'sort']);

type ParamValue = string | number | boolean | (string | number)[] | undefined;

/**
 * Transforms flat SDK params into Ransack-compatible query params.
 *
 * - `page`, `per_page`, `includes`, `include`, `sort` pass through unchanged
 * - Keys already in `q[...]` format pass through (backward compat)
 * - All other keys are wrapped: `name_cont` → `q[name_cont]`
 */
export function transformListParams(
  params: Record<string, unknown>
): Record<string, ParamValue> {
  const result: Record<string, ParamValue> = {};

  for (const [key, value] of Object.entries(params)) {
    if (value === undefined) continue;

    if (PASSTHROUGH_KEYS.has(key)) {
      result[key] = value as ParamValue;
      continue;
    }

    // Backward compat: already-wrapped q[...] keys pass through
    if (key.startsWith('q[')) {
      result[key] = value as ParamValue;
      continue;
    }

    // Handle array bracket keys: `foo[]` → `q[foo][]`
    if (key.endsWith('[]')) {
      const base = key.slice(0, -2);
      result[`q[${base}][]`] = value as ParamValue;
    } else {
      result[`q[${key}]`] = value as ParamValue;
    }
  }

  return result;
}
