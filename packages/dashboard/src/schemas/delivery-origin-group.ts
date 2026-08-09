import { z } from 'zod/v4'

/**
 * One origin group of a delivery profile. An empty name is the nameless
 * default group, which the UI renders as "All locations"; an empty
 * `stock_location_ids` means the group ships from every store location.
 */
export const deliveryOriginGroupFormSchema = z.object({
  name: z.string(),
  stock_location_ids: z.array(z.string()),
})

export type DeliveryOriginGroupFormValues = z.infer<typeof deliveryOriginGroupFormSchema>

export const DELIVERY_ORIGIN_GROUP_DEFAULTS: DeliveryOriginGroupFormValues = {
  name: '',
  stock_location_ids: [],
}

export function deliveryOriginGroupValuesToParams(values: DeliveryOriginGroupFormValues) {
  return {
    name: values.name.trim() || null,
    stock_location_ids: values.stock_location_ids,
  }
}
