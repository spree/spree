import type { DeliveryMethodRule } from '@spree/admin-sdk'
import { isDecimalString, isZeroMoney } from '@spree/core'
import { formatAmount, listedAmounts } from '@spree/dashboard-core'
import type { TFunction } from 'i18next'

/**
 * A stored preference as a decimal string. The API answers with strings; a
 * number still sitting in preferences saved before 6.0 is read as its digits.
 */
function toDecimal(value: unknown): string | null {
  const text =
    typeof value === 'number' ? String(value) : typeof value === 'string' ? value.trim() : ''
  return isDecimalString(text) ? text : null
}

/**
 * The flat amount a calculator-priced method charges, or null when it is
 * priced some other way (per item, tiered, per carrier quote) and has no
 * single number to show. Prefer `listedAmounts` when the currency matters.
 */
export function flatAmount(preferences: Record<string, unknown> | null | undefined): string | null {
  return toDecimal(preferences?.amount)
}

/**
 * The glance price for a calculator-priced method on the delivery profile
 * list. Each stored amount is formatted in its own currency; zero-only or
 * empty preferences read as free.
 */
export function formatListedPrice(
  preferences: Record<string, unknown> | null | undefined,
  defaultCurrency: string,
  locale: string | undefined,
  freeLabel: string,
  separator: string,
): string {
  const priced = listedAmounts(preferences, defaultCurrency).filter(
    (row) => !isZeroMoney(row.amount),
  )
  if (priced.length === 0) return freeLabel
  return priced.map((row) => formatAmount(row.amount, row.currency, locale)).join(separator)
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
    const min = toDecimal(preferences.minimum_weight)
    const max = toDecimal(preferences.maximum_weight)
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
    const min = toDecimal(preferences.minimum_amount)
    const max = toDecimal(preferences.maximum_amount)
    const money = (value: string) => formatAmount(value, currency, locale)
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
