import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { describe, expect, it } from 'vitest'
import {
  CURRENCY_EXPONENTS,
  compareMoney,
  decimalPlaces,
  formatMoney,
  fractionToPercent,
  isDecimalString,
  isPositiveMoney,
  isZeroMoney,
  multiplyMoney,
  negateMoney,
  percentOf,
  percentToFraction,
  prorateMoney,
  shiftDecimalPoint,
  subtractMoney,
  sumMoney,
} from '../src'

describe('money helpers', () => {
  it('reads the same ISO 4217 table as Spree', () => {
    const core = JSON.parse(
      readFileSync(
        resolve(__dirname, '../../../spree/core/config/currency_exponents.json'),
        'utf-8',
      ),
    )
    expect(CURRENCY_EXPONENTS).toEqual(core)
  })

  it('knows each currency’s decimals', () => {
    expect([
      decimalPlaces('USD'),
      decimalPlaces('jpy'),
      decimalPlaces('KWD'),
      decimalPlaces('ZZZ'),
    ]).toEqual([2, 0, 3, 2])
  })

  it('adds exactly where floats drift', () => {
    expect(sumMoney(['0.1', '0.2'])).toBe('0.3')
    expect(sumMoney(['0.1', '0.2'], 'USD')).toBe('0.30')
    expect(sumMoney(['1.500', '0.005'], 'KWD')).toBe('1.505')
    expect(sumMoney(['100', '200'], 'JPY')).toBe('300')
    expect(sumMoney([null, '', '19.99'], 'USD')).toBe('19.99')
  })

  it('keeps the decimals its inputs carry', () => {
    expect(sumMoney(['1.50', '2.50'])).toBe('4.00')
    expect(subtractMoney('5.00', '1.00')).toBe('4.00')
    expect(multiplyMoney('0.10', 3)).toBe('0.30')
    expect(multiplyMoney('19.999', 3, 'USD')).toBe('59.997')
    expect(multiplyMoney('5', 2, 'USD')).toBe('10.00')
    expect(negateMoney('0.00')).toBe('0.00')
  })

  it('subtracts and multiplies exactly', () => {
    expect(subtractMoney('10.00', '10.01', 'USD')).toBe('-0.01')
    expect(multiplyMoney('0.0125', 3)).toBe('0.0375')
    expect(multiplyMoney('19.99', 3, 'USD')).toBe('59.97')
  })

  it('compares and tests for zero', () => {
    expect(compareMoney('10.0', '10.00')).toBe(0)
    expect(compareMoney('9.99', '10')).toBe(-1)
    expect(compareMoney('-1', '-2')).toBe(1)
    expect([
      isZeroMoney('0.00'),
      isZeroMoney('-0.0'),
      isZeroMoney(''),
      isZeroMoney('0.01'),
    ]).toEqual([true, true, true, false])
  })

  it('accepts only canonical decimal strings', () => {
    expect([
      isDecimalString('19.99'),
      isDecimalString('1,99'),
      isDecimalString(19.99),
      isDecimalString('1e3'),
    ]).toEqual([true, false, false, false])
    expect(() => sumMoney(['1,99'])).toThrow()
  })

  it('formats an amount in its currency and the reader’s language', () => {
    expect(formatMoney('1234.5', 'USD', 'en')).toBe('$1,234.50')
    expect(formatMoney('1234.5', 'EUR', 'de')).toBe('1.234,50\u00a0€')
    expect(formatMoney('1000', 'JPY', 'en')).toBe('¥1,000')
    expect(formatMoney('1.5', 'KWD', 'en')).toBe('KWD\u00a01.500')
    expect(formatMoney('0.0125', 'USD', 'en', { unitPrice: true })).toBe('$0.0125')
    expect(formatMoney('99999999999999999.99', 'USD', 'en')).toBe('$99,999,999,999,999,999.99')
    expect([formatMoney(null, 'USD'), formatMoney('1,99', 'USD')]).toEqual(['', ''])
  })

  it('formats without throwing on an unknown currency or locale', () => {
    expect(formatMoney('10', '', 'en')).toBe('')
    expect(formatMoney('10', 'USD', 'en_US')).toBe(formatMoney('10', 'USD'))
    expect(formatMoney('-0.001', 'USD', 'en')).toBe('$0.00')
    expect(formatMoney('-0.005', 'USD', 'en')).toBe('-$0.01')
  })
})

describe('shiftDecimalPoint', () => {
  it('moves the point exactly, without float noise', () => {
    expect(shiftDecimalPoint('0.077', 2)).toBe('7.7')
    expect(shiftDecimalPoint('7.7', -2)).toBe('0.077')
    expect(shiftDecimalPoint('0.07', 2)).toBe('7')
    expect(shiftDecimalPoint('1', 2)).toBe('100')
    expect(shiftDecimalPoint('100', -2)).toBe('1')
    expect(shiftDecimalPoint('-0.5', 2)).toBe('-50')
    expect(shiftDecimalPoint('0', -2)).toBe('0')
  })

  it('leaves a value that is not a decimal string alone', () => {
    expect(shiftDecimalPoint('abc', 2)).toBe('abc')
  })
})

describe('fractionToPercent / percentToFraction', () => {
  it('round-trips and keeps blanks blank', () => {
    expect(fractionToPercent('0.23')).toBe('23')
    expect(percentToFraction('23')).toBe('0.23')
    expect(percentToFraction('7.25')).toBe('0.0725')
    expect(fractionToPercent(null)).toBe('')
    expect(percentToFraction('')).toBe('')
  })
})

describe('percentOf', () => {
  it('rounds to the currency decimals', () => {
    expect(percentOf('19.99', '10', 'USD')).toBe('2.00')
    expect(percentOf('100', '12.5', 'USD')).toBe('12.50')
    expect(percentOf('1000', '0.05', 'JPY')).toBe('1')
    expect(percentOf('1.005', '50', 'KWD')).toBe('0.503')
  })
})

describe('isPositiveMoney', () => {
  it('is true only for an amount above zero', () => {
    expect(isPositiveMoney('0.01')).toBe(true)
    expect(isPositiveMoney('0.00')).toBe(false)
    expect(isPositiveMoney('-1')).toBe(false)
    expect(isPositiveMoney(null)).toBe(false)
    expect(isPositiveMoney('abc')).toBe(false)
  })
})

describe('prorateMoney', () => {
  it('shares an amount across units, rounded to the currency', () => {
    expect(prorateMoney('10.00', 1, 3, 'USD')).toBe('3.33')
    expect(prorateMoney('10.00', 2, 3, 'USD')).toBe('6.67')
    expect(prorateMoney('10.00', 3, 3, 'USD')).toBe('10.00')
    expect(prorateMoney('1000', 1, 3, 'JPY')).toBe('333')
  })
})
