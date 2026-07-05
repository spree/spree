import { i18n } from '@spree/dashboard-core'
import { requiredMessage } from '@spree/dashboard-ui'
import { z } from 'zod/v4'

const customerProfileBase = z.object({
  // Server requires a valid email; check client-side so the user gets an
  // inline error rather than a 422 round-trip.
  email: z
    .string()
    .trim()
    .min(1, { error: requiredMessage('email') })
    .email({ error: () => i18n.t('admin.validation.invalid_email') }),
  first_name: z.string(),
  last_name: z.string(),
  phone: z.string(),
  tags: z.array(z.string()),
  accepts_email_marketing: z.boolean(),
})

export const customerProfileFormSchema = customerProfileBase
export type CustomerProfileFormValues = z.infer<typeof customerProfileFormSchema>

// New-customer sheet adds an inline `internal_note` — existing customers edit
// the note in its own card, so it's omitted from the profile schema.
export const newCustomerFormSchema = customerProfileBase.extend({
  internal_note: z.string(),
})
export type NewCustomerFormValues = z.infer<typeof newCustomerFormSchema>

export const NEW_CUSTOMER_DEFAULTS: NewCustomerFormValues = {
  email: '',
  first_name: '',
  last_name: '',
  phone: '',
  tags: [],
  accepts_email_marketing: false,
  internal_note: '',
}
