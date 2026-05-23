import { z } from 'zod/v4'
import { i18n } from '@/lib/i18n'
import { requiredMessage } from '@/lib/validation-messages'

const amountPositive = () =>
  i18n.t('admin.validation.positive_number', {
    field: i18n.t('admin.fields.store_credit.amount.label'),
  })

// Amount stays a string in the form (Input value), validated against
// "positive numeric" without coercing — the submit handler does the coercion
// so we can preserve trim/blank semantics.
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
