import { z } from 'zod/v4'

/**
 * Creating a profile: the kind is fixed at creation because it decides which
 * fulfillment providers the profile's methods may use.
 */
export const deliveryProfileCreateSchema = z.object({
  name: z.string().min(1),
  kind: z.string().min(1),
  /** Display-only, mirroring the detail page: "all" sends an empty id list. */
  origins_scope: z.enum(['all', 'selected']),
  stock_location_ids: z.array(z.string()),
})

export type DeliveryProfileCreateValues = z.infer<typeof deliveryProfileCreateSchema>

export const DELIVERY_PROFILE_CREATE_DEFAULTS: DeliveryProfileCreateValues = {
  name: '',
  kind: 'shipping',
  origins_scope: 'all',
  stock_location_ids: [],
}

/** The general card on the profile detail page — kind is read-only once set. */
export const deliveryProfileGeneralSchema = z.object({
  name: z.string().min(1),
})

export type DeliveryProfileGeneralValues = z.infer<typeof deliveryProfileGeneralSchema>

/**
 * Origins card. `scope` is display-only state: "all" clears the id list, so
 * an empty list still means every store location on the wire.
 */
export const deliveryProfileLocationsSchema = z.object({
  scope: z.enum(['all', 'selected']),
  stock_location_ids: z.array(z.string()),
})

export type DeliveryProfileLocationsValues = z.infer<typeof deliveryProfileLocationsSchema>

export function deliveryProfileLocationsToParams(values: DeliveryProfileLocationsValues) {
  return { stock_location_ids: values.scope === 'all' ? [] : values.stock_location_ids }
}
