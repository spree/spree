/**
 * Mirrors ActiveSupport's `String#parameterize`: lowercase, ASCII-friendly,
 * hyphen-separated. Keeps a code preview in step with what `normalizes :code`
 * produces on the model, so an operator sees the final slug as they type.
 */
export function slugify(value: string): string {
  return value
    .normalize('NFKD')
    .replace(/\p{M}/gu, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
}
