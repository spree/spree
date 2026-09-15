import { describe, expect, it } from 'vitest'

import { normalizeCalculatorType, resolveCalculatorType } from './promotion-calculator-type'

const catalog = [{ type: 'flat_percent_item_total' }, { type: 'flat_rate' }, { type: 'flexi_rate' }]

describe('normalizeCalculatorType', () => {
  it('passes through api shorthand unchanged', () => {
    expect(normalizeCalculatorType('flat_rate')).toBe('flat_rate')
  })

  it('derives api shorthand from a Ruby class name', () => {
    expect(normalizeCalculatorType('Spree::Calculator::FlatRate')).toBe('flat_rate')
    expect(normalizeCalculatorType('Spree::Calculator::FlatPercentItemTotal')).toBe(
      'flat_percent_item_total',
    )
  })
})

describe('resolveCalculatorType', () => {
  it('matches catalog entries by api shorthand', () => {
    expect(resolveCalculatorType(catalog, 'flat_rate')).toBe('flat_rate')
  })

  it('matches catalog entries when the draft carries a Ruby class name', () => {
    expect(resolveCalculatorType(catalog, 'Spree::Calculator::FlatRate')).toBe('flat_rate')
  })

  it('returns undefined when nothing matches', () => {
    expect(resolveCalculatorType(catalog, 'Spree::Calculator::Gone')).toBeUndefined()
  })
})
