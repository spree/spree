import type { DeliveryMethodRule } from '@spree/admin-sdk'
import type { TFunction } from 'i18next'

/**
 * The flat amount a calculator-priced method charges, or null when it is
 * priced some other way (per item, tiered, per carrier quote) and has no
 * single number to show.
 */
export function flatAmount(preferences: Record<string, unknown> | null | undefined): number | null {
  const amount = preferences?.amount
  if (amount === null || amount === undefined || amount === '') return null
  const parsed = Number(amount)
  return Number.isNaN(parsed) ? null : parsed
}

/** Formats an amount in the store's currency, falling back to a bare number. */
export function formatAmount(amount: number, currency: string, locale?: string): string {
  try {
    return new Intl.NumberFormat(locale, { style: 'currency', currency }).format(amount)
  } catch {
    return `${amount} ${currency}`
  }
}

function toNumber(value: unknown): number | null {
  if (value === null || value === undefined || value === '') return null
  const parsed = Number(value)
  return Number.isNaN(parsed) ? null : parsed
}

interface RuleSummaryContext {
  t: TFunction
  /** Currency the item-total bounds are quoted in. */
  currency: string
  /** The store's weight unit ('kg' or 'lb') — weight rules carry no unit of their own. */
  weightUnit: string
  locale?: string
}

/**
 * A compact reading of one rule's bounds — "20kg and up", "Under $50",
 * "$100 and up". Returns null for rules with no bounds set (a half-configured
 * rule passes everything, so it has nothing to announce) and for kinds whose
 * shape is a list rather than a range.
 */
function summarizeRule(
  rule: Pick<DeliveryMethodRule, 'type' | 'preferences'>,
  { t, currency, weightUnit, locale }: RuleSummaryContext,
): string | null {
  const preferences = (rule.preferences ?? {}) as Record<string, unknown>

  if (rule.type === 'weight_rule') {
    const min = toNumber(preferences.minimum_weight)
    const max = toNumber(preferences.maximum_weight)
    if (min !== null && max !== null) {
      return t('admin.delivery_methods.rule_summary.weight_between', {
        min,
        max,
        unit: weightUnit,
      })
    }
    if (min !== null) {
      return t('admin.delivery_methods.rule_summary.weight_min', { min, unit: weightUnit })
    }
    if (max !== null) {
      return t('admin.delivery_methods.rule_summary.weight_max', { max, unit: weightUnit })
    }
    return null
  }

  if (rule.type === 'item_total_rule') {
    const min = toNumber(preferences.minimum_amount)
    const max = toNumber(preferences.maximum_amount)
    const money = (value: number) => formatAmount(value, currency, locale)
    if (min !== null && max !== null) {
      return t('admin.delivery_methods.rule_summary.total_between', {
        min: money(min),
        max: money(max),
      })
    }
    if (min !== null) return t('admin.delivery_methods.rule_summary.total_min', { min: money(min) })
    if (max !== null) return t('admin.delivery_methods.rule_summary.total_max', { max: money(max) })
    return null
  }

  return null
}

/**
 * One line summarizing every bound a method's rules impose, for the method
 * rows on the delivery profile page. Empty when the method is eligible
 * everywhere, so the caller renders nothing.
 */
export function summarizeRules(
  rules: Pick<DeliveryMethodRule, 'type' | 'preferences'>[] | null | undefined,
  context: RuleSummaryContext,
): string | null {
  const parts = (rules ?? [])
    .map((rule) => summarizeRule(rule, context))
    .filter((part): part is string => part !== null)

  return parts.length > 0
    ? parts.join(context.t('admin.delivery_methods.rule_summary.separator'))
    : null
}
