import { z } from 'zod/v4'
import type { VariantLine } from '../components/spree/variant-line-editor'

/**
 * A variant carried into a new transfer or purchase order through the URL, so
 * a merchant who clicks "Create transfer" from an Inventory row lands on the
 * form with that SKU already on it.
 *
 * The row is passed rather than looked up again: the Inventory list already
 * holds the name, SKU and image the line renders, and a form that refetched
 * them would open empty for as long as the request took. Every field is
 * optional so a hand-typed or stale link still opens a usable, empty form.
 */
export const prefilledVariantSchema = z.object({
  variant_id: z.string().optional(),
  variant_sku: z.string().optional(),
  variant_name: z.string().optional(),
  thumbnail_url: z.string().optional(),
  stock_location_id: z.string().optional(),
})

export type PrefilledVariantSearch = z.infer<typeof prefilledVariantSchema>

/** The line to open the document with, or none when no variant was named. */
export function prefilledLines(search: PrefilledVariantSearch, withCost: boolean): VariantLine[] {
  if (!search.variant_id) return []

  return [
    {
      variant: {
        id: search.variant_id,
        sku: search.variant_sku ?? null,
        product_name: search.variant_name ?? null,
        thumbnail_url: search.thumbnail_url ?? null,
      },
      quantity: 1,
      unitCost: withCost ? '0.00' : undefined,
    },
  ]
}
