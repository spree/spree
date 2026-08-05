import { requiredMessage } from '@spree/dashboard-ui'
import { z } from 'zod/v4'

/** Shared by return, claim and refund reasons — all three carry the same two fields. */
export const reasonFormSchema = z.object({
  name: z.string().min(1, { error: requiredMessage('name') }),
  active: z.boolean(),
})

export type ReasonFormValues = z.infer<typeof reasonFormSchema>

export const REASON_DEFAULTS: ReasonFormValues = {
  name: '',
  active: true,
}
