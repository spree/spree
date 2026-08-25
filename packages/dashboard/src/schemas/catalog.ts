import type { CatalogParams } from '@spree/admin-sdk'
import { blankToNull } from '@spree/dashboard-core'
import { requiredMessage } from '@spree/dashboard-ui'
import { z } from 'zod/v4'

export const catalogFormSchema = z.object({
  name: z.string().min(1, { error: requiredMessage('name') }),
  active: z.boolean(),
  // Empty string = assortment-only (base prices).
  price_list_id: z.string().optional(),
})

export type CatalogFormValues = z.infer<typeof catalogFormSchema>

export const CATALOG_DEFAULTS: CatalogFormValues = { name: '', active: true, price_list_id: '' }

export function catalogValuesToParams(values: CatalogFormValues): CatalogParams {
  return {
    name: values.name,
    active: values.active,
    price_list_id: blankToNull(values.price_list_id),
  }
}
