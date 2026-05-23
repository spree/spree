/**
 * Treat a blank or whitespace-only string as "not set" — common when mapping
 * form values to API params, where a blank `<input>` should become `undefined`
 * (omit the field) or `null` (clear the server value) rather than passing the
 * empty string through.
 */
export function blankToUndefined(s: string | null | undefined): string | undefined {
  return s && s.length > 0 ? s : undefined
}

export function blankToNull(s: string | null | undefined): string | null {
  return s && s.length > 0 ? s : null
}
