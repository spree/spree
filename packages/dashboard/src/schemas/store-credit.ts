import { i18n } from '@spree/dashboard-core'
import { requiredMessage } from '@spree/dashboard-ui'
import { z } from 'zod/v4'

const amountPositive = () =>
  i18n.t('admin.validation.positive_number', {
    field: i18n.t('admin.fields.store_credit.amount.label'),
  })

// Amount stays a string end-to-end (form Input value and wire payload),
// validated against "positive numeric" without coercing. The backend's
// LocalizedNumber.parse decodes it, so we never Number()-coerce — that would
// mangle localized input like "1.234,56" to NaN.
const amountField = z
  .string()
  .trim()
  .refine((v) => v !== '' && Number.isFinite(Number(v)) && Number(v) > 0, {
    error: amountPositive,
  })

export const issueStoreCreditFormSchema = z.object({
  amount: amountField,
  currency: z.string().min(1, { error: requiredMessage('currency') }),
  category_id: z.string().min(1, { error: requiredMessage('store_credit.category_id') }),
  memo: z.string(),
})

export type IssueStoreCreditFormValues = z.infer<typeof issueStoreCreditFormSchema>

// Edit allows blank amount (means "no change") but if provided must be > 0.
export const editStoreCreditFormSchema = z.object({
  amount: z
    .string()
    .trim()
    .refine((v) => v === '' || (Number.isFinite(Number(v)) && Number(v) > 0), {
      error: amountPositive,
    }),
  category_id: z.string(),
  memo: z.string(),
})

export type EditStoreCreditFormValues = z.infer<typeof editStoreCreditFormSchema>
