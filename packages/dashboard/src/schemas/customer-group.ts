import type { CustomerGroupCreateParams, CustomerGroupUpdateParams } from '@spree/admin-sdk'
import { requiredMessage } from '@spree/dashboard-ui'
import { z } from 'zod/v4'
import { blankToNull } from '@/lib/form-mappers'

export const customerGroupFormSchema = z.object({
  name: z
    .string()
    .trim()
    .min(1, { error: requiredMessage('name') }),
  description: z.string().trim().optional(),
})

export type CustomerGroupFormValues = z.infer<typeof customerGroupFormSchema>

export const CUSTOMER_GROUP_DEFAULTS: CustomerGroupFormValues = { name: '', description: '' }

export function customerGroupValuesToParams(
  v: CustomerGroupFormValues,
): CustomerGroupCreateParams & CustomerGroupUpdateParams {
  return {
    name: v.name,
    description: blankToNull(v.description),
  }
}
