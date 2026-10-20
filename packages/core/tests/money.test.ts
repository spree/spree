import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { describe, expect, it } from 'vitest'
import {
  CURRENCY_EXPONENTS,
  compareMoney,
  decimalPlaces,
  formatMoney,
  isDecimalString,
  isZeroMoney,
  multiplyMoney,
  negateMoney,
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
