import { variantFormSchema } from '@spree/dashboard-core'
import { z } from 'zod'

/**
 * What a seller fills in when listing an offer against one of the
 * marketplace's products (docs/plans/6.0-seller-master-catalog-listings.md).
 *
 * The offer itself is one variant row, held under `variants` as a
 * single-element array rather than flat at the root. That shape is what lets
 * the seller panel render the operator's own price and inventory
 * spreadsheets, which read a product form's `variants` collection — the
 * alternative was a second pair of hand-rolled inputs drifting away from
 * them.
 *
 * Built from `variantFormSchema` rather than re-declaring its fields: the two
 * had already drifted on quantity rules and price coercion, and the shared
 * field sections assume core's types.
 */
const offerRowSchema = variantFormSchema
  .omit({
    // Tax is marketplace configuration, and the order of a shared product's
    // rows is the operator's — neither is a seller's to send.
    tax_category_id: true,
    position: true,
  })
  .extend({
    /** Blank ships the offer the way the master product does. */
    delivery_profile_id: z.string().nullable().optional(),
    cost_price: z.union([z.string(), z.number()]).nullable().optional(),
  })

export const offerFormSchema = z.object({
  // One row, always. `useFieldArray` is deliberately absent: a seller does
  // not add variants to somebody else's product, they list one offer against
  // it.
  variants: z.array(offerRowSchema).length(1),
})

export type OfferFormValues = z.infer<typeof offerFormSchema>
export type OfferRowValues = z.infer<typeof offerRowSchema>

/** A blank offer, before the master product's option axes are known. */
export function newOfferFormDefaults(): OfferFormValues {
  return {
    variants: [
      {
        options: [],
        prices: [],
        stock_levels: [],
        track_inventory: true,
        preorderable: false,
      },
    ],
  }
}
