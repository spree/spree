/**
 * Base for documentation links surfaced in the dashboard.
 *
 * Kept in one place so a docs restructure, a domain change or a locale prefix
 * is a single edit rather than a sweep through every table and settings page.
 */
export const DOCS_BASE_URL = 'https://spreecommerce.org/docs'

/**
 * Resolves a documentation path to a full URL.
 *
 * A bare path is taken as relative to the user guide, which is where the
 * merchant-facing pages live; an absolute URL is returned untouched, so a
 * plugin can point at its own documentation.
 *
 * @param path - `'catalogs'`, `'developer/providers/erp'`, or a full URL
 * @returns the URL to link to
 */
export function docsUrl(path: string): string {
  if (/^https?:\/\//.test(path)) return path

  const trimmed = path.replace(/^\/+/, '')
  const section = /^(user|developer)\//.test(trimmed) ? trimmed : `user/${trimmed}`
  return `${DOCS_BASE_URL}/${section}`
}
