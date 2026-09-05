import { z } from 'zod'

/**
 * What a seller fills in when listing an offer against one of the
 * marketplace's products (docs/plans/6.0-seller-master-catalog-listings.md).
 *
 * Deliberately shallow, and holding no SDK entity types: react-hook-form's
 * `Path<T>` walks every nested key, and the SDK records embed the whole
 * object graph. The master product being listed against is display-only
 * state the page holds outside the form.
 */
export const offerFormSchema = z.object({
  sku: z.string().optional(),
  barcode: z.string().optional(),

  /** One entry per option type the master product is sold by. */
  options: z.array(z.object({ name: z.string(), value: z.string().min(1) })).default([]),

  /** At least one is needed before the offer can be submitted for review. */
  prices: z
    .array(
      z.object({
        currency: z.string(),
        amount: z.union([z.string(), z.number()]).optional(),
      }),
    )
    .default([]),

  stock_levels: z
    .array(
      z.object({
        id: z.string().optional(),
        stock_location_id: z.string(),
        count_on_hand: z.coerce.number().int().min(0).optional(),
      }),
    )
    .default([]),

  /** Blank ships the offer the way the master product does. */
  delivery_profile_id: z.string().nullable().optional(),

  cost_price: z.union([z.string(), z.number()]).nullable().optional(),
  weight: z.union([z.string(), z.number()]).nullable().optional(),
  height: z.union([z.string(), z.number()]).nullable().optional(),
  width: z.union([z.string(), z.number()]).nullable().optional(),
  depth: z.union([z.string(), z.number()]).nullable().optional(),
  weight_unit: z.string().nullable().optional(),
  dimensions_unit: z.string().nullable().optional(),

  hs_code: z.string().nullable().optional(),
  country_of_origin: z.string().nullable().optional(),
  customs_description: z.string().nullable().optional(),

  minimum_order_quantity: z.coerce.number().int().positive().nullable().optional(),
  order_multiple: z.coerce.number().int().positive().nullable().optional(),
  purchase_unit: z.string().nullable().optional(),
  units_per_carton: z.coerce.number().int().positive().nullable().optional(),

  track_inventory: z.boolean().optional(),
  preorderable: z.boolean().optional(),
  preorder_ships_at: z.string().nullable().optional(),
  backorder_limit: z.coerce.number().int().min(0).nullable().optional(),
})

export type OfferFormValues = z.infer<typeof offerFormSchema>

/** A blank offer, before the master product's option axes are known. */
export function newOfferFormDefaults(): OfferFormValues {
  return {
    options: [],
    prices: [],
    stock_levels: [],
    track_inventory: true,
    preorderable: false,
  }
}
