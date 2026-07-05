/**
 * Treat a blank or whitespace-only string as "not set" — common when mapping
 * form values to API params, where a blank `<input>` should become `undefined`
 * (omit the field) or `null` (clear the server value) rather than passing the
 * empty string through. Returns the trimmed value when present.
 */
export function blankToUndefined(s: string | null | undefined): string | undefined {
  const trimmed = s?.trim()
  return trimmed ? trimmed : undefined
}

export function blankToNull(s: string | null | undefined): string | null {
  const trimmed = s?.trim()
  return trimmed ? trimmed : null
}

/**
 * Preprocessor for Zod optional-number fields backed by `<input type="number">`.
 * Empty inputs return `''`, which `z.coerce.number()` would coerce to `0` —
 * tripping `.positive()` / `.min()` on otherwise-optional fields. Map empty
 * to `undefined` so the optional branch wins.
 *
 * ```ts
 * usage_limit: z.preprocess(emptyToUndefined, z.coerce.number().int().positive().optional())
 * ```
 */
export function emptyToUndefined(value: unknown): unknown {
  if (value === '' || value === null) return undefined
  return value
}
