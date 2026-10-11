import { i18n } from '@spree/dashboard-core'
import { requiredMessage } from '@spree/dashboard-ui'
import { z } from 'zod/v4'

const amountPositive = () =>
  i18n.t('admin.validation.positive_number', {
    field: i18n.t('admin.fields.store_credit.amount.label'),
  })

// Amount stays a string end-to-end (form Input value and wire payload) and is
// normalized from the admin's number format on submit, so we never
// Number()-coerce — that would turn "1.234,56" into NaN. We only assert the
// shape here: at least one non-zero digit (so "0"/"0.00" are rejected as not
// strictly positive), no leading minus, digits/separators/spaces only.
// Authoritative parsing happens server-side.
const isPositiveAmountString = (v: string) => /^(?!-)(?=.*[1-9])[\d.,\s]+$/.test(v)

const amountField = z
  .string()
  .trim()
  .refine((v) => v !== '' && isPositiveAmountString(v), {
    error: amountPositive,
  })

export const issueStoreCreditFormSchema = z.object({
  customer_id: z.string().min(1, { error: requiredMessage('customer_id') }),
  amount: amountField,
  currency: z.string().min(1, { error: requiredMessage('currency') }),
  memo: z.string(),
})

export type IssueStoreCreditFormValues = z.infer<typeof issueStoreCreditFormSchema>

// Edit allows blank amount (means "no change") but if provided must be > 0.
export const editStoreCreditFormSchema = z.object({
  amount: z
    .string()
    .trim()
    .refine((v) => v === '' || isPositiveAmountString(v), {
      error: amountPositive,
    }),
  memo: z.string(),
})

export type EditStoreCreditFormValues = z.infer<typeof editStoreCreditFormSchema>
