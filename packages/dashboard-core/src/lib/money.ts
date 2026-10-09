import { compareMoney, decimalPlaces, isDecimalString, sumMoney } from '@spree/admin-sdk'

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

function scaled(value: string): { units: bigint; scale: number } {
  const negative = value.startsWith('-')
  const [whole, fraction = ''] = (negative ? value.slice(1) : value).split('.')
  const units = BigInt(whole + fraction)
  return { units: negative ? -units : units, scale: fraction.length }
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
  const left = scaled(amount)
  const right = scaled(percent)
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
  const { units, scale } = scaled(amount)
  return roundToCurrency(units * BigInt(part), scale, BigInt(whole), currency)
}
