import type { ImportType } from '@spree/admin-sdk'

/**
 * Example CSVs published from Spree's `core/db/sample_data`. These are the same
 * files `rake spree:load_sample_data` feeds through the import pipeline, so they
 * are working examples rather than hand-written samples that drift from the
 * schema.
 *
 * Keyed by the API's type shorthand (`"products"`), which is also the CSV's
 * filename stem — so this is just the set of types that have an example file.
 */
const TYPES_WITH_SAMPLE_CSV = new Set(['products', 'customers', 'product_translations'])

const SAMPLE_CSV_BASE_URL =
  'https://raw.githubusercontent.com/spree/spree/refs/heads/main/spree/core/db/sample_data'

/**
 * Public URL of the example CSV for an import type, or `null` for a type that
 * has no sample file — callers omit the link rather than render a 404.
 */
export function sampleCsvUrl(type: ImportType): string | null {
  return TYPES_WITH_SAMPLE_CSV.has(type) ? `${SAMPLE_CSV_BASE_URL}/${type}.csv` : null
}
