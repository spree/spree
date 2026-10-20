import { CURRENCY_EXPONENTS } from './currency-exponents'

// Money arrives from the API as canonical decimal strings ("1234.56"). These
// helpers work on those strings through scaled bigints, so no amount passes
// through a JS number on the way to a comparison or a sum.

const CANONICAL = /^-?\d+(\.\d+)?$/

interface Scaled {
  units: bigint
  scale: number
}

function parse(value: string): Scaled {
  if (!CANONICAL.test(value)) throw new Error(`Not a decimal string: ${JSON.stringify(value)}`)

  const negative = value.startsWith('-')
  const [whole, fraction = ''] = (negative ? value.slice(1) : value).split('.')
  const units = BigInt(whole + fraction)
  return { units: negative ? -units : units, scale: fraction.length }
}

function rescale(scaled: Scaled, scale: number): bigint {
  return scaled.units * 10n ** BigInt(scale - scaled.scale)
}

function write(units: bigint, scale: number): string {
  const negative = units < 0n
  const digits = (negative ? -units : units).toString().padStart(scale + 1, '0')
  const text = scale > 0 ? `${digits.slice(0, -scale)}.${digits.slice(-scale)}` : digits
  return negative ? `-${text}` : text
}

// Results keep every decimal their inputs carry and, with a currency, at
// least that currency's decimals, so "1.50" + "2.50" reads "4.00" and nothing
// is ever rounded away.
function resultScale(scales: number[], currency?: string): number {
  return Math.max(0, currency ? decimalPlaces(currency) : 0, ...scales)
}

/**
 * The decimals amounts in a currency are written with (ISO 4217): 2 for USD,
 * 0 for JPY, 3 for KWD. An unknown code answers 2.
 */
export function decimalPlaces(currency: string): number {
  return CURRENCY_EXPONENTS[currency.toUpperCase()] ?? 2
}

/** Whether a value is a canonical decimal string such as "19.99". */
export function isDecimalString(value: unknown): value is string {
  return typeof value === 'string' && CANONICAL.test(value)
}

/** -1, 0 or 1, comparing two decimal strings exactly. */
export function compareMoney(a: string, b: string): -1 | 0 | 1 {
  const left = parse(a)
  const right = parse(b)
  const scale = Math.max(left.scale, right.scale)
  const difference = rescale(left, scale) - rescale(right, scale)
  return difference === 0n ? 0 : difference > 0n ? 1 : -1
}

/** Whether a decimal string is zero ("0", "0.00", "-0.0"). Blank counts as zero. */
export function isZeroMoney(value: string | null | undefined): boolean {
  if (value == null || value === '') return true
  return parse(value).units === 0n
}

/**
 * Adds decimal strings exactly. Blank values count as zero. The result keeps
 * the most decimals any value has, and at least the currency's when one is
 * given ("10.00").
 */
export function sumMoney(values: Array<string | null | undefined>, currency?: string): string {
  const present = values
    .filter((value): value is string => value != null && value !== '')
    .map(parse)
  const scale = resultScale(
    present.map((value) => value.scale),
    currency,
  )
  const total = present.reduce((sum, value) => sum + rescale(value, scale), 0n)
  return write(total, scale)
}

/** a minus b, exactly. */
export function subtractMoney(a: string, b: string, currency?: string): string {
  return sumMoney([a, negateMoney(b)], currency)
}

/** The decimal string with its sign flipped. */
export function negateMoney(value: string): string {
  const { units, scale } = parse(value)
  return write(-units, scale)
}

/**
 * A decimal string times a whole quantity, exactly. A unit price with four
 * decimals keeps them ("19.9990" × 3 = "59.9970"); round with the currency
 * when displaying, through `formatMoney`.
 */
export function multiplyMoney(value: string, quantity: number, currency?: string): string {
  if (!Number.isInteger(quantity)) throw new Error(`Quantity must be a whole number: ${quantity}`)

  const parsed = parse(value)
  const scale = resultScale([parsed.scale], currency)
  return write(rescale(parsed, scale) * BigInt(quantity), scale)
}

/**
 * Formats a decimal-string amount ("1234.50") in a currency and locale. The
 * string goes to `Intl` as it is — `Intl` reads numeric strings exactly — so
 * the amount never passes through a JavaScript number. A missing or malformed
 * amount, or a currency `Intl` does not know, formats as an empty string; a
 * locale it does not know falls back to the reader's own.
 *
 * @example formatMoney(order.total, order.currency, order.locale) // "€129.99"
 */
export function formatMoney(
  amount: string | null | undefined,
  currency: string,
  locale?: string | null,
  options: { unitPrice?: boolean } = {},
): string {
  if (!isDecimalString(amount)) return ''

  // The decimals come from the same ISO 4217 table the API writes amounts
  // with, so a dinar shows three and a yen none; a unit price keeps up to four.
  const places = decimalPlaces(currency)
  const maximumPlaces = options.unitPrice ? Math.max(places, 4) : places
  // An amount that rounds to zero shows no minus sign ("-0.001" is "$0.00").
  const shown =
    amount.startsWith('-') && roundsToZero(amount.slice(1), maximumPlaces)
      ? amount.slice(1)
      : amount
  const format = (formatLocale: string | undefined) =>
    // ES2023's Intl typings accept a numeric string; this package targets ES2022.
    new Intl.NumberFormat(formatLocale, {
      style: 'currency',
      currency,
      minimumFractionDigits: places,
      maximumFractionDigits: maximumPlaces,
    }).format(shown as unknown as number)

  for (const formatLocale of locale ? [locale, undefined] : [undefined]) {
    try {
      return format(formatLocale)
    } catch (error) {
      if (!(error instanceof RangeError)) throw error
    }
  }
  return ''
}

function roundsToZero(amount: string, places: number): boolean {
  return compareMoney(amount, `0.${'0'.repeat(places)}5`) < 0
}

/** Whether an amount is a decimal string above zero. Blank or malformed is not. */
export function isPositiveMoney(value: string | null | undefined): boolean {
  return isDecimalString(value) && compareMoney(value, '0') > 0
}

/**
 * Moves the decimal point of a decimal string by whole places, exactly, and
 * writes the result without trailing zeros ("0.077" shifted by 2 is "7.7").
 * Anything that is not a decimal string comes back unchanged.
 */
export function shiftDecimalPoint(value: string, places: number): string {
  if (!isDecimalString(value)) return value

  const negative = value.startsWith('-')
  const [whole, fraction = ''] = (negative ? value.slice(1) : value).split('.')
  let digits = whole + fraction
  let point = whole.length + places
  if (point < 0) {
    digits = '0'.repeat(-point) + digits
    point = 0
  }
  digits = digits.padEnd(point, '0')

  const integer = digits.slice(0, point).replace(/^0+(?=\d)/, '') || '0'
  const decimals = digits.slice(point).replace(/0+$/, '')
  const text = decimals ? `${integer}.${decimals}` : integer
  return negative && /[1-9]/.test(text) ? `-${text}` : text
}

/** A fraction rate ("0.23") as the percentage a merchant reads ("23"). Blank stays blank. */
export function fractionToPercent(fraction: string | null | undefined): string {
  return fraction == null || fraction === '' ? '' : shiftDecimalPoint(fraction, 2)
}

/** A typed percentage ("23") as the fraction rate the API stores ("0.23"). Blank stays blank. */
export function percentToFraction(percent: string | null | undefined): string {
  return percent == null || percent === '' ? '' : shiftDecimalPoint(percent.trim(), -2)
}

/**
 * numerator / denominator, where the numerator carries `scale` decimals,
 * rounded half away from zero to the currency's decimals.
 */
function roundToCurrency(
  numerator: bigint,
  scale: number,
  denominator: bigint,
  currency: string,
): string {
  const places = decimalPlaces(currency)
  const negative = numerator < 0n !== denominator < 0n
  let dividend = numerator < 0n ? -numerator : numerator
  let divisor = denominator < 0n ? -denominator : denominator
  if (scale > places) divisor *= 10n ** BigInt(scale - places)
  else dividend *= 10n ** BigInt(places - scale)

  let units = dividend / divisor
  if ((dividend % divisor) * 2n >= divisor) units += 1n

  const text = shiftDecimalPoint((negative ? -units : units).toString(), -places)
  return sumMoney([text], currency)
}

/**
 * A percentage of an amount, exactly, rounded half away from zero to the
 * currency's decimals ("10" percent of "19.99" USD is "2.00").
 */
export function percentOf(amount: string, percent: string, currency: string): string {
  const left = parse(amount)
  const right = parse(percent)
  // The percentage is a hundredth, so the product carries two more places.
  return roundToCurrency(left.units * right.units, left.scale + right.scale + 2, 1n, currency)
}

/**
 * The share of an amount that `part` of `whole` units carries ("10.00" for 1
 * of 3 is "3.33"), rounded half away from zero to the currency's decimals.
 */
export function prorateMoney(
  amount: string,
  part: number,
  whole: number,
  currency: string,
): string {
  if (!Number.isInteger(part) || !Number.isInteger(whole) || whole === 0) {
    throw new Error(`Cannot prorate ${part} of ${whole}`)
  }
  const { units, scale } = parse(amount)
  return roundToCurrency(units * BigInt(part), scale, BigInt(whole), currency)
}
