import type { TaxCategoryCreateParams, TaxCategoryUpdateParams } from '@spree/admin-sdk'
import { blankToNull } from '@spree/dashboard-core'
import { requiredMessage } from '@spree/dashboard-ui'
import { z } from 'zod/v4'

export const taxCategoryFormSchema = z.object({
  name: z.string().min(1, { error: requiredMessage('name') }),
  tax_code: z.string().optional(),
  description: z.string().optional(),
  is_default: z.boolean(),
})

export type TaxCategoryFormValues = z.infer<typeof taxCategoryFormSchema>

export const TAX_CATEGORY_DEFAULTS: TaxCategoryFormValues = {
  name: '',
  tax_code: '',
  description: '',
  is_default: false,
}

export function taxCategoryValuesToParams(
  v: TaxCategoryFormValues,
): TaxCategoryCreateParams & TaxCategoryUpdateParams {
  return {
    name: v.name,
    tax_code: blankToNull(v.tax_code),
    description: blankToNull(v.description),
    is_default: v.is_default,
  }
}
