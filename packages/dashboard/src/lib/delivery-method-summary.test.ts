import { describe, expect, it } from 'vitest'
import { formatListedPrice } from './delivery-method-summary'

describe('formatListedPrice', () => {
  const separator = ' · '

  it('formats a default-currency amount with that currency symbol', () => {
    expect(formatListedPrice({ amount: '5' }, 'USD', 'en', 'Free', separator)).toBe('$5.00')
  })

  it('formats an EUR-only method with a euro sign, not the store default symbol', () => {
    expect(formatListedPrice({ amounts: { EUR: '7' } }, 'USD', 'en', 'Free', separator)).toBe(
      '€7.00',
    )
  })

  it('formats a GBP-only method with a pound sign', () => {
    expect(formatListedPrice({ amounts: { GBP: '8' } }, 'USD', 'en', 'Free', separator)).toBe(
      '£8.00',
    )
  })

  it('joins one price per stored currency', () => {
    expect(
      formatListedPrice({ amounts: { USD: '5', EUR: '7' } }, 'USD', 'en', 'Free', separator),
    ).toBe('$5.00 · €7.00')
  })

  it('reads an empty or zero-only method as free', () => {
    expect(formatListedPrice({}, 'USD', 'en', 'Free', separator)).toBe('Free')
    expect(formatListedPrice({ amount: '0' }, 'USD', 'en', 'Free', separator)).toBe('Free')
    expect(formatListedPrice({ amounts: { EUR: '0' } }, 'USD', 'en', 'Free', separator)).toBe(
      'Free',
    )
  })

  it('does not read a zero single amount as free when the hash has a real price', () => {
    expect(
      formatListedPrice({ amount: '0', amounts: { EUR: '11' } }, 'USD', 'en', 'Free', separator),
    ).toBe('€11.00')
  })
})
