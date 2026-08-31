import { describe, expect, it } from 'vitest'
import {
  amountForCurrency,
  applyCurrencyAmount,
  formatListedPrice,
  listedAmounts,
} from './delivery-method-summary'

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

  it('reads the editor-written hash even when the single amount is zero', () => {
    expect(listedAmounts({ amount: 0, amounts: { EUR: 11 } }, 'USD')).toEqual([
      { amount: 0, currency: 'USD' },
      { amount: 11, currency: 'EUR' },
    ])
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

  it('does not read a zero single amount as free when the hash has a real price', () => {
    expect(
      formatListedPrice({ amount: 0, amounts: { EUR: 11 } }, 'USD', 'en', 'Free', separator),
    ).toBe('€11.00')
  })
})

describe('amountForCurrency', () => {
  it('puts a pre-6.0 euro amount in the euro row, not the store default', () => {
    const preferences = { amount: 7, currency: 'EUR' }
    expect(amountForCurrency(preferences, 'EUR', 'USD')).toBe(7)
    expect(amountForCurrency(preferences, 'USD', 'USD')).toBeNull()
  })

  it('reads an editor-written euro price from the amounts hash', () => {
    const preferences = { amount: 0, amounts: { EUR: 11 } }
    expect(amountForCurrency(preferences, 'EUR', 'USD')).toBe(11)
    expect(amountForCurrency(preferences, 'USD', 'USD')).toBe(0)
  })

  it('treats a blank currency preference as the store default', () => {
    expect(amountForCurrency({ amount: 5 }, 'USD', 'USD')).toBe(5)
    expect(amountForCurrency({ amount: 5 }, 'EUR', 'USD')).toBeNull()
  })

  it('trims surrounding space on the legacy currency preference', () => {
    const preferences = { amount: 7, currency: ' EUR ' }
    expect(amountForCurrency(preferences, 'EUR', 'USD')).toBe(7)
    expect(amountForCurrency(preferences, 'USD', 'USD')).toBeNull()
  })

  it('reads a lowercase amounts-hash key as that currency', () => {
    expect(amountForCurrency({ amounts: { eur: 7 } }, 'EUR', 'USD')).toBe(7)
  })
})

describe('applyCurrencyAmount', () => {
  it('keeps a pre-6.0 euro price when the dollar row is edited', () => {
    expect(applyCurrencyAmount({ amount: 7, currency: 'EUR' }, 'USD', '10', 'USD')).toEqual({
      amount: 10,
      currency: 'USD',
      amounts: { EUR: 7 },
    })
  })

  it('updates the named currency in place on a pre-6.0 method', () => {
    expect(applyCurrencyAmount({ amount: 7, currency: 'EUR' }, 'EUR', '11', 'USD')).toEqual({
      amount: 11,
      currency: 'EUR',
      amounts: { EUR: 11 },
    })
  })

  it('writes a non-default currency into the amounts hash', () => {
    expect(applyCurrencyAmount({ amount: 5, currency: 'USD' }, 'EUR', '11', 'USD')).toEqual({
      amount: 5,
      currency: 'USD',
      amounts: { EUR: 11 },
    })
  })

  it('updates and clears a lowercase stored hash key without leaving a stale entry', () => {
    expect(applyCurrencyAmount({ amounts: { eur: 7 } }, 'EUR', '11', 'USD')).toEqual({
      amounts: { EUR: 11 },
    })
    expect(applyCurrencyAmount({ amounts: { eur: 7 } }, 'EUR', '', 'USD')).toEqual({
      amounts: {},
    })
  })
})
