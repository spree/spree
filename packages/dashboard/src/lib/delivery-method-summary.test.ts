import { describe, expect, it } from 'vitest'
import { formatListedPrice, listedAmounts } from './delivery-method-summary'

describe('listedAmounts', () => {
  it('reads the legacy single amount as the store default currency', () => {
    expect(listedAmounts({ amount: 5 }, 'USD')).toEqual([{ amount: 5, currency: 'USD' }])
  })

  it('attributes the legacy amount to its own currency preference', () => {
    expect(listedAmounts({ amount: 7, currency: 'EUR' }, 'USD')).toEqual([
      { amount: 7, currency: 'EUR' },
    ])
  })

  it('reads a non-default currency from the amounts hash when the default is empty', () => {
    expect(listedAmounts({ amounts: { EUR: 7 } }, 'USD')).toEqual([{ amount: 7, currency: 'EUR' }])
  })

  it('keeps each hash amount against the currency it was entered in', () => {
    expect(listedAmounts({ amounts: { GBP: 8, EUR: 7 } }, 'USD')).toEqual([
      { amount: 7, currency: 'EUR' },
      { amount: 8, currency: 'GBP' },
    ])
  })

  it('lists the default-currency amount first when both sources have a price', () => {
    expect(listedAmounts({ amount: 5, amounts: { EUR: 7 } }, 'USD')).toEqual([
      { amount: 5, currency: 'USD' },
      { amount: 7, currency: 'EUR' },
    ])
  })

  it('lets the amounts hash override the legacy amount for the same currency', () => {
    expect(listedAmounts({ amount: 5, amounts: { USD: 6, EUR: 7 } }, 'USD')).toEqual([
      { amount: 6, currency: 'USD' },
      { amount: 7, currency: 'EUR' },
    ])
  })

  it('ignores blank hash entries so an emptied currency is not offered', () => {
    expect(listedAmounts({ amounts: { EUR: '', GBP: 8 } }, 'USD')).toEqual([
      { amount: 8, currency: 'GBP' },
    ])
  })
})

describe('formatListedPrice', () => {
  const separator = ' · '

  it('formats a default-currency amount with that currency symbol', () => {
    expect(formatListedPrice({ amount: 5 }, 'USD', 'en', 'Free', separator)).toBe('$5.00')
  })

  it('formats an EUR-only method with a euro sign, not the store default symbol', () => {
    expect(formatListedPrice({ amounts: { EUR: 7 } }, 'USD', 'en', 'Free', separator)).toBe('€7.00')
  })

  it('formats a GBP-only method with a pound sign', () => {
    expect(formatListedPrice({ amounts: { GBP: 8 } }, 'USD', 'en', 'Free', separator)).toBe('£8.00')
  })

  it('joins one price per stored currency', () => {
    expect(
      formatListedPrice({ amount: 5, amounts: { EUR: 7 } }, 'USD', 'en', 'Free', separator),
    ).toBe('$5.00 · €7.00')
  })

  it('reads an empty or zero-only method as free', () => {
    expect(formatListedPrice({}, 'USD', 'en', 'Free', separator)).toBe('Free')
    expect(formatListedPrice({ amount: 0 }, 'USD', 'en', 'Free', separator)).toBe('Free')
    expect(formatListedPrice({ amounts: { EUR: 0 } }, 'USD', 'en', 'Free', separator)).toBe('Free')
  })
})
