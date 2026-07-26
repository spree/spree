import type { ImportType } from '@spree/admin-sdk'

/**
 * Import types that ship a populated example CSV in Spree's
 * `core/db/sample_data`. Keyed by the API's type shorthand (`"products"`),
 * which is also the CSV's filename stem.
 *
 * Only used to decide whether to render the download link — the file itself is
 * served by `GET /api/v3/admin/imports/example`, which pins the URL to the
 * installed Spree version. A type missing from this list simply hides the link;
 * the endpoint is the authority and 404s for anything it has no example for.
 */
const TYPES_WITH_SAMPLE_CSV = new Set(['products', 'customers', 'product_translations'])

/** Whether an import type has an example CSV to offer. */
export function hasSampleCsv(type: ImportType): boolean {
  return TYPES_WITH_SAMPLE_CSV.has(type)
}
