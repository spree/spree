import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { describe, expect, it } from 'vitest'
import { CURRENCY_EXPONENTS } from '../../sdk-core/src/currency-exponents'
import {
  compareMoney,
  decimalPlaces,
  isDecimalString,
  isZeroMoney,
  multiplyMoney,
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
})
