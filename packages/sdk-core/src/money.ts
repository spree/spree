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

function write(units: bigint, scale: number, places = 0): string {
  const negative = units < 0n
  const digits = (negative ? -units : units).toString().padStart(scale + 1, '0')
  const whole = scale > 0 ? digits.slice(0, -scale) : digits
  let fraction = scale > 0 ? digits.slice(-scale) : ''
  fraction = fraction.replace(/0+$/, '').padEnd(places, '0')
  const text = fraction ? `${whole}.${fraction}` : whole
  return negative && /[1-9]/.test(text) ? `-${text}` : text
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
 * Adds decimal strings exactly. Blank values count as zero. With a currency,
 * the result is written with that currency's decimals ("10.00").
 */
export function sumMoney(values: Array<string | null | undefined>, currency?: string): string {
  const present = values
    .filter((value): value is string => value != null && value !== '')
    .map(parse)
  const scale = Math.max(
    0,
    currency ? decimalPlaces(currency) : 0,
    ...present.map((value) => value.scale),
  )
  const total = present.reduce((sum, value) => sum + rescale(value, scale), 0n)
  return write(total, scale, currency ? decimalPlaces(currency) : 0)
}

/** a minus b, exactly. */
export function subtractMoney(a: string, b: string, currency?: string): string {
  return sumMoney([a, negateMoney(b)], currency)
}

/** The decimal string with its sign flipped. */
export function negateMoney(value: string): string {
  const { units, scale } = parse(value)
  return write(-units, scale, scale)
}

/** A decimal string times a whole quantity, exactly. */
export function multiplyMoney(value: string, quantity: number, currency?: string): string {
  if (!Number.isInteger(quantity)) throw new Error(`Quantity must be a whole number: ${quantity}`)

  const { units, scale } = parse(value)
  return write(units * BigInt(quantity), scale, currency ? decimalPlaces(currency) : scale)
}
