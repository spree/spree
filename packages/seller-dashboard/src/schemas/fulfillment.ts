import { z } from 'zod/v4'

/**
 * What the seller chose to send out of one parcel: per-line quantities plus
 * the tracking number and whether the customer hears about it.
 *
 * Every line the parcel holds gets a row, so an unselected row means "leave
 * this one behind" rather than being absent — the payload drops the
 * unselected rows on submit.
 *
 * The upper bound is per row (how many units that parcel holds), so it lives
 * on the field rather than in the schema; the schema only enforces that a
 * quantity is a whole number that is not negative. Sending nothing at all is
 * prevented by disabling the submit, since it is a no-op rather than a
 * validation failure.
 */
export const fulfillItemsFormSchema = z.object({
  items: z.array(
    z.object({
      item_id: z.string(),
      selected: z.boolean(),
      quantity: z.number().int().min(0),
    }),
  ),
  tracking: z.string(),
  // '' = detect from the number; slugs come from trackingCarriers.list().
  tracking_carrier: z.string(),
  notify_customer: z.boolean(),
})

export type FulfillItemsFormValues = z.infer<typeof fulfillItemsFormSchema>

/** The tracking pair, edited after a parcel has gone out. */
export const trackingFormSchema = z.object({
  tracking: z.string(),
  tracking_carrier: z.string(),
})

export type TrackingFormValues = z.infer<typeof trackingFormSchema>
