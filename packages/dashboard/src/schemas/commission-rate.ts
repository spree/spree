import type {
  CommissionRate,
  CommissionRateCreateParams,
  CommissionRateUpdateParams,
} from '@spree/admin-sdk'
import { blankToNull } from '@spree/dashboard-core'
import { requiredMessage } from '@spree/dashboard-ui'
import { z } from 'zod/v4'

export const COMMISSION_RATE_KINDS = ['percentage', 'fixed'] as const

export const commissionRateFormSchema = z.object({
  name: z.string().min(1, { error: requiredMessage('name') }),
  code: z.string().optional(),
  enabled: z.boolean(),
  kind: z.enum(COMMISSION_RATE_KINDS),
  value: z.coerce.number().min(0),
  currency: z.string().optional(),
  include_tax: z.boolean(),
  include_shipping: z.boolean(),
  min_amount: z.string().optional(),
  max_amount: z.string().optional(),
  // Held as a percentage in the form because that is how merchants think about
  // VAT; converted to the fraction the API stores on the way out.
  commission_tax_rate: z.string().optional(),
  // Shallow on purpose: react-hook-form's `Path<T>` walks every nested key, so
  // an SDK entity here would drag its whole object graph into the form type.
  // The pickers resolve their own labels, so an id is all the form carries.
  rules: z.array(
    z.object({
      subject_type: z.string(),
      subject_id: z.string(),
    }),
  ),
})

export type CommissionRateFormValues = z.infer<typeof commissionRateFormSchema>

export const COMMISSION_RATE_DEFAULTS: CommissionRateFormValues = {
  name: '',
  code: '',
  enabled: true,
  kind: 'percentage',
  value: 10,
  currency: '',
  include_tax: false,
  include_shipping: false,
  min_amount: '',
  max_amount: '',
  commission_tax_rate: '',
  rules: [],
}

export function commissionRateToFormValues(rate: CommissionRate): CommissionRateFormValues {
  return {
    name: rate.name,
    code: rate.code ?? '',
    enabled: rate.enabled,
    kind: (rate.kind as CommissionRateFormValues['kind']) ?? 'percentage',
    value: Number(rate.value ?? 0),
    currency: rate.currency ?? '',
    include_tax: rate.include_tax,
    include_shipping: rate.include_shipping,
    min_amount: rate.min_amount == null ? '' : String(rate.min_amount),
    max_amount: rate.max_amount == null ? '' : String(rate.max_amount),
    commission_tax_rate:
      rate.commission_tax_rate == null ? '' : String(Number(rate.commission_tax_rate) * 100),
    rules: (rate.rules ?? []).map((rule) => ({
      subject_type: rule.subject_type ?? '',
      subject_id: rule.subject_id ?? '',
    })),
  }
}

function decimalOrNull(value: string | undefined): number | null {
  const trimmed = value?.trim()
  return trimmed ? Number(trimmed) : null
}

export function commissionRateValuesToParams(
  v: CommissionRateFormValues,
): CommissionRateCreateParams & CommissionRateUpdateParams {
  const taxPercentage = decimalOrNull(v.commission_tax_rate)

  return {
    name: v.name,
    code: blankToNull(v.code),
    enabled: v.enabled,
    kind: v.kind,
    value: v.value,
    // A percentage applies in any currency, so sending one would only be
    // noise the server ignores.
    currency: v.kind === 'fixed' ? blankToNull(v.currency) : null,
    include_tax: v.include_tax,
    include_shipping: v.include_shipping,
    min_amount: decimalOrNull(v.min_amount),
    max_amount: decimalOrNull(v.max_amount),
    commission_tax_rate: taxPercentage === null ? null : taxPercentage / 100,
    rules: v.rules,
  }
}
