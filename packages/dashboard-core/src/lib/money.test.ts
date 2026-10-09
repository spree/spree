import { describe, expect, it } from 'vitest'
import {
  fractionToPercent,
  isPositiveMoney,
  percentOf,
  percentToFraction,
  prorateMoney,
  shiftDecimalPoint,
} from './money'

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
