import type { CustomerGroupCreateParams, CustomerGroupUpdateParams } from '@spree/admin-sdk'
import { z } from 'zod/v4'
import { requiredMessage } from '@/lib/validation-messages'

export const customerGroupFormSchema = z.object({
  name: z.string().min(1, { error: requiredMessage('name') }),
  description: z.string().optional(),
})

export type CustomerGroupFormValues = z.infer<typeof customerGroupFormSchema>

export const CUSTOMER_GROUP_DEFAULTS: CustomerGroupFormValues = { name: '', description: '' }

export function customerGroupValuesToParams(
  v: CustomerGroupFormValues,
): CustomerGroupCreateParams & CustomerGroupUpdateParams {
  return {
    name: v.name,
    description: v.description && v.description.length > 0 ? v.description : null,
  }
}
