import { i18n } from '@spree/dashboard-core'
import { z } from 'zod/v4'

/**
 * What the merchant chose to ship out of one fulfillment: per-item quantities
 * plus the tracking number and whether the customer hears about it.
 *
 * Every item the fulfillment holds gets a row, so an unselected row means
 * "leave this one behind" rather than being absent — the payload drops the
 * unselected rows on submit.
 *
 * The upper bound is per row (how many units that fulfillment holds), so it
 * lives on the field rather than in the schema; the schema only enforces that
 * a quantity is a whole number that is not negative. Shipping nothing at all
 * is prevented by disabling the submit, since it is a no-op rather than a
 * validation failure.
 */
export const fulfillItemsFormSchema = z.object({
  items: z.array(
    z.object({
      item_id: z.string(),
      selected: z.boolean(),
      quantity: z
        .number({ error: () => i18n.t('admin.orders.fulfill.validation.quantity_invalid') })
        .int({ error: () => i18n.t('admin.orders.fulfill.validation.quantity_invalid') })
        .min(0, { error: () => i18n.t('admin.orders.fulfill.validation.quantity_invalid') }),
    }),
  ),
  tracking: z.string(),
  notify_customer: z.boolean(),
})

export type FulfillItemsFormValues = z.infer<typeof fulfillItemsFormSchema>
