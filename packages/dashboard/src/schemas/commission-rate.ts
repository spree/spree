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
  // What a flat fee charges, keyed by currency. Held as strings because they
  // come from number inputs and an empty one means "not charged here".
  amounts: z.record(z.string(), z.string()).default({}),
  // The floor and cap a percentage charges within, keyed by currency. Each
  // holds only in its own currency, so a rate may bound some and leave the
  // rest unbounded rather than have a figure converted on its behalf.
  bounds: z
    .record(z.string(), z.object({ min_amount: z.string(), max_amount: z.string() }))
    .default({}),
  tax_inclusive: z.boolean(),
  include_shipping: z.boolean(),
  // Held as a percentage in the form because that is how merchants think about
  // VAT; converted to the fraction the API stores on the way out.
  commission_tax_rate: z.string().optional(),
  // Shallow on purpose: react-hook-form's `Path<T>` walks every nested key, so
  // an SDK entity here would drag its whole object graph into the form type.
  // Pickers resolve their own labels, so ids are all the form carries.
  rules: z.array(
    z.object({
      id: z.string().optional(),
      type: z.string(),
      preferences: z.record(z.string(), z.unknown()).default({}),
      // Catalog-scale references ride beside preferences, not inside them.
      product_ids: z.array(z.string()).default([]),
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
  amounts: {},
  bounds: {},
  tax_inclusive: false,
  include_shipping: false,
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
    amounts: Object.fromEntries(
      Object.entries(rate.amounts ?? {}).map(([code, amount]) => [code, String(amount ?? '')]),
    ),
    bounds: Object.fromEntries(
      Object.entries(rate.bounds ?? {}).map(([code, bound]) => [
        code,
        {
          min_amount: bound?.min_amount == null ? '' : String(bound.min_amount),
          max_amount: bound?.max_amount == null ? '' : String(bound.max_amount),
        },
      ]),
    ),
    tax_inclusive: rate.tax_inclusive,
    include_shipping: rate.include_shipping,
    commission_tax_rate:
      rate.commission_tax_rate == null ? '' : String(Number(rate.commission_tax_rate) * 100),
    rules: (rate.rules ?? []).map((rule) => ({
      id: rule.id,
      type: rule.type,
      preferences: (rule.preferences ?? {}) as Record<string, unknown>,
      product_ids: rule.product_ids ?? [],
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
    amounts:
      v.kind === 'fixed'
        ? Object.fromEntries(
            Object.entries(v.amounts).filter(([, amount]) => String(amount ?? '').trim() !== ''),
          )
        : {},
    tax_inclusive: v.tax_inclusive,
    // Only a percentage can charge delivery; a flat fee already charges for
    // the sale a parcel belongs to.
    include_shipping: v.kind === 'percentage' ? v.include_shipping : false,
    // A currency the merchant left blank carries no bound, so it is left out
    // entirely rather than sent as a pair of nulls.
    bounds: Object.fromEntries(
      Object.entries(v.bounds)
        .map(([code, bound]) => [
          code,
          {
            min_amount: decimalOrNull(bound.min_amount),
            max_amount: decimalOrNull(bound.max_amount),
          },
        ])
        .filter(([, bound]) => {
          const { min_amount, max_amount } = bound as {
            min_amount: number | null
            max_amount: number | null
          }
          return min_amount !== null || max_amount !== null
        }),
    ),
    commission_tax_rate: taxPercentage === null ? null : taxPercentage / 100,
    // `product_ids` is only meaningful to kinds that name products; sending an
    // empty array to the others is noise the server would ignore.
    rules: v.rules.map((rule) => ({
      id: rule.id,
      type: rule.type,
      preferences: rule.preferences,
      ...(rule.product_ids.length > 0 ? { product_ids: rule.product_ids } : {}),
    })),
  }
}
