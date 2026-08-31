import type { DeliveryMethodRule } from '@spree/admin-sdk'
import type { TFunction } from 'i18next'

function toNumber(value: unknown): number | null {
  if (value === null || value === undefined || value === '') return null
  const parsed = Number(value)
  return Number.isNaN(parsed) ? null : parsed
}

export type ListedAmount = {
  amount: number
  currency: string
}

/**
 * Every amount a calculator-priced method quotes, each with the currency it
 * belongs to. The per-currency `amounts` hash is the source of truth; the
 * legacy single `amount` fills in for its own currency (the `currency`
 * preference, or the store default) when the hash has no entry there.
 *
 * A method priced only in a non-default currency therefore returns that
 * currency's row, not a number that the caller would stamp with the store
 * default's symbol.
 */
export function listedAmounts(
  preferences: Record<string, unknown> | null | undefined,
  defaultCurrency: string,
): ListedAmount[] {
  const listed: ListedAmount[] = []
  const seen = new Set<string>()
  const defaultCode = defaultCurrency.toUpperCase()

  const amounts = preferences?.amounts
  if (amounts && typeof amounts === 'object' && !Array.isArray(amounts)) {
    for (const [code, value] of Object.entries(amounts as Record<string, unknown>)) {
      const parsed = toNumber(value)
      if (parsed === null) continue
      const currency = code.toUpperCase()
      listed.push({ amount: parsed, currency })
      seen.add(currency)
    }
  }

  const legacyAmount = toNumber(preferences?.amount)
  if (legacyAmount !== null) {
    const rawCurrency =
      typeof preferences?.currency === 'string' && preferences.currency.trim() !== ''
        ? preferences.currency
        : defaultCurrency
    const legacyCurrency = rawCurrency.toUpperCase()
    if (!seen.has(legacyCurrency)) {
      listed.push({ amount: legacyAmount, currency: legacyCurrency })
    }
  }

  return listed.sort((left, right) => {
    if (left.currency === defaultCode) return -1
    if (right.currency === defaultCode) return 1
    return left.currency.localeCompare(right.currency)
  })
}

/**
 * The flat amount a calculator-priced method charges, or null when it is
 * priced some other way (per item, tiered, per carrier quote) and has no
 * single number to show. Prefer `listedAmounts` when the currency matters.
 */
export function flatAmount(preferences: Record<string, unknown> | null | undefined): number | null {
  return toNumber(preferences?.amount)
}

/** Formats an amount in the given currency, falling back to a bare number. */
export function formatAmount(amount: number, currency: string, locale?: string): string {
  try {
    return new Intl.NumberFormat(locale, { style: 'currency', currency }).format(amount)
  } catch {
    return `${amount} ${currency}`
  }
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
  const priced = listedAmounts(preferences, defaultCurrency).filter((row) => row.amount !== 0)
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
