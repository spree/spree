import type { TaxRateParams } from '@spree/admin-sdk'
import { blankToNull } from '@spree/dashboard-core'
import { requiredMessage } from '@spree/dashboard-ui'
import { z } from 'zod/v4'

export const taxRateFormSchema = z.object({
  name: z.string().min(1, { error: requiredMessage('name') }),
  // The merchant types a percentage (20), the API stores a fraction (0.2).
  amount_percentage: z.coerce.number().min(0).max(100),
  // Required: a rate always taxes exactly one category.
  tax_category_id: z.string().min(1, { error: requiredMessage('tax_rate.tax_category_id') }),
  // Empty means the rate applies everywhere, so neither field is required.
  country_iso: z.string().optional(),
  state_code: z.string().optional(),
  included_in_price: z.boolean(),
  show_rate_in_label: z.boolean(),
})

export type TaxRateFormValues = z.infer<typeof taxRateFormSchema>

export const TAX_RATE_DEFAULTS: TaxRateFormValues = {
  name: '',
  amount_percentage: 0,
  tax_category_id: '',
  country_iso: '',
  state_code: '',
  included_in_price: false,
  show_rate_in_label: false,
}

/**
 * A blank jurisdiction field is sent as null rather than omitted: clearing the
 * country on an existing rate has to widen it back to everywhere, which an
 * omitted key would not do.
 */
export function taxRateValuesToParams(values: TaxRateFormValues): TaxRateParams {
  return {
    name: values.name,
    amount: values.amount_percentage / 100,
    tax_category_id: values.tax_category_id,
    country_iso: blankToNull(values.country_iso),
    state_code: blankToNull(values.state_code),
    included_in_price: values.included_in_price,
    show_rate_in_label: values.show_rate_in_label,
  }
}
