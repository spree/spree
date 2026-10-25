import { isDecimalString } from '@spree/core'

/**
 * Delivery calculators whose price is a plain amount, quoted per currency
 * through the `amounts` preference. Every other calculator (percent, tiered)
 * is currency-neutral.
 */
export const AMOUNT_BASED_CALCULATORS: readonly string[] = [
  'flat_rate',
  'per_item',
  'digital_delivery',
]

/** The preferences the per-currency editor owns on those calculators. */
export const CURRENCY_AMOUNT_KEYS: readonly string[] = ['amount', 'currency', 'amounts']

/**
 * A stored preference as a decimal string. The API answers with strings; a
 * number still sitting in preferences saved before 6.0 is read as its digits.
 */
function toDecimal(value: unknown): string | null {
  const text =
    typeof value === 'number' ? String(value) : typeof value === 'string' ? value.trim() : ''
  return isDecimalString(text) ? text : null
}

/** One stored delivery amount and the ISO currency it was entered in. */
export type ListedAmount = {
  amount: string
  currency: string
}

function amountsHash(
  preferences: Record<string, unknown> | null | undefined,
): Record<string, unknown> {
  const amounts = preferences?.amounts
  if (!amounts || typeof amounts !== 'object' || Array.isArray(amounts)) return {}
  return amounts as Record<string, unknown>
}

function hashKey(amounts: Record<string, unknown>, currency: string): string | undefined {
  const code = currency.toUpperCase()
  return Object.keys(amounts).find((key) => key.toUpperCase() === code)
}

function hashEntry(amounts: Record<string, unknown>, currency: string): unknown {
  const key = hashKey(amounts, currency)
  return key === undefined ? undefined : amounts[key]
}

function writeHashAmount(
  amounts: Record<string, unknown>,
  currency: string,
  value: string | null,
): void {
  const existing = hashKey(amounts, currency)
  if (existing !== undefined) delete amounts[existing]
  if (value !== null) amounts[currency.toUpperCase()] = value
}

/** The currency the pre-6.0 single `amount` belongs to. */
function legacyCurrency(
  preferences: Record<string, unknown> | null | undefined,
  defaultCurrency: string,
): string {
  if (typeof preferences?.currency === 'string' && preferences.currency.trim() !== '') {
    return preferences.currency.trim().toUpperCase()
  }
  return defaultCurrency.toUpperCase()
}

/** Whether the per-currency hash holds an amount: from then on it alone decides. */
function hasAmounts(amounts: Record<string, unknown>): boolean {
  return Object.values(amounts).some((value) => toDecimal(value) !== null)
}

/**
 * The amount a calculator-priced method quotes for one currency — the same
 * rule the calculator uses. Once the per-currency `amounts` hash holds an
 * amount it alone decides; the legacy single `amount` quotes its own
 * currency (the `currency` preference, or the store default when that
 * preference is blank) only while the hash is empty.
 *
 * A pre-6.0 method that names EUR therefore returns 7 for EUR and nothing
 * for USD.
 */
export function amountForCurrency(
  preferences: Record<string, unknown> | null | undefined,
  currency: string,
  defaultCurrency: string,
): string | null {
  const code = currency.toUpperCase()
  const amounts = amountsHash(preferences)
  if (hasAmounts(amounts)) return toDecimal(hashEntry(amounts, code))

  if (legacyCurrency(preferences, defaultCurrency) !== code) return null
  return toDecimal(preferences?.amount)
}

/**
 * Writes one currency's amount the way the delivery-method editor does: into
 * the per-currency `amounts` hash, the store default like every other
 * currency, and a cleared currency removed so the method is not offered in
 * it.
 *
 * The first edit of a method priced with the legacy single `amount` moves
 * that figure into the hash under its own currency, since the hash alone
 * decides once it holds an amount, and clears the single amount. Amounts are
 * written as the exact decimal string typed, which is what the API accepts.
 */
export function applyCurrencyAmount(
  preferences: Record<string, unknown>,
  currency: string,
  raw: string,
  defaultCurrency: string,
): Record<string, unknown> {
  const current = amountsHash(preferences)
  const nextAmounts: Record<string, unknown> = hasAmounts(current) ? { ...current } : {}

  if (!hasAmounts(current)) {
    const legacy = toDecimal(preferences.amount)
    if (legacy !== null) nextAmounts[legacyCurrency(preferences, defaultCurrency)] = legacy
  }

  writeHashAmount(nextAmounts, currency, toDecimal(raw))
  return { ...preferences, amount: null, amounts: nextAmounts }
}

/**
 * Whether a calculator-priced method states an amount in any currency. One
 * without any would never be offered.
 */
export function hasCurrencyAmount(
  preferences: Record<string, unknown> | null | undefined,
): boolean {
  return hasAmounts(amountsHash(preferences)) || toDecimal(preferences?.amount) !== null
}

/**
 * Every amount a calculator-priced method quotes, each with the currency it
 * belongs to. The per-currency `amounts` hash decides once it holds an
 * amount; the legacy single `amount` stands for its own currency (the
 * `currency` preference, or the store default) only while the hash is empty.
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
  const defaultCode = defaultCurrency.toUpperCase()

  for (const [code, value] of Object.entries(amountsHash(preferences))) {
    const parsed = toDecimal(value)
    if (parsed === null) continue
    listed.push({ amount: parsed, currency: code.toUpperCase() })
  }

  const legacyAmount = toDecimal(preferences?.amount)
  if (listed.length === 0 && legacyAmount !== null) {
    listed.push({ amount: legacyAmount, currency: legacyCurrency(preferences, defaultCurrency) })
  }

  return listed.sort((left, right) => {
    if (left.currency === defaultCode) return -1
    if (right.currency === defaultCode) return 1
    return left.currency.localeCompare(right.currency)
  })
}
