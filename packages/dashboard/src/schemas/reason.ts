import { requiredMessage } from '@spree/dashboard-ui'
import { z } from 'zod/v4'

/** Shared by every reason vocabulary — they all carry a name and an active flag. */
export const reasonFormSchema = z.object({
  name: z.string().min(1, { error: requiredMessage('name') }),
  active: z.boolean(),
  code: z.string().optional(),
})

/** Tax exemption reasons also carry the code certificates record and a tax engine reads. */
export const taxExemptionReasonFormSchema = reasonFormSchema.extend({
  code: z
    .string()
    .trim()
    .min(1, { error: requiredMessage('code') }),
})

export type ReasonFormValues = z.infer<typeof reasonFormSchema>

export const REASON_DEFAULTS: ReasonFormValues = {
  name: '',
  active: true,
  code: '',
}
