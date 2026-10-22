import { describe, expect, it } from 'vitest'
import {
  amountForCurrency,
  applyCurrencyAmount,
  hasCurrencyAmount,
  listedAmounts,
} from './currency-amounts'

describe('listedAmounts', () => {
  it('reads the legacy single amount as the store default currency', () => {
    expect(listedAmounts({ amount: '5' }, 'USD')).toEqual([{ amount: '5', currency: 'USD' }])
  })

  it('attributes the legacy amount to its own currency preference', () => {
    expect(listedAmounts({ amount: '7', currency: 'EUR' }, 'USD')).toEqual([
      { amount: '7', currency: 'EUR' },
    ])
  })

  it('reads a non-default currency from the amounts hash when the default is empty', () => {
    expect(listedAmounts({ amounts: { EUR: '7' } }, 'USD')).toEqual([
      { amount: '7', currency: 'EUR' },
    ])
  })

  it('ignores the single amount once the hash holds an amount, as the server does', () => {
    expect(listedAmounts({ amount: '0', amounts: { EUR: '11' } }, 'USD')).toEqual([
      { amount: '11', currency: 'EUR' },
    ])
  })

  it('keeps each hash amount against the currency it was entered in', () => {
    expect(listedAmounts({ amounts: { GBP: '8', EUR: '7' } }, 'USD')).toEqual([
      { amount: '7', currency: 'EUR' },
      { amount: '8', currency: 'GBP' },
    ])
  })

  it('lists the default-currency amount first', () => {
    expect(listedAmounts({ amounts: { EUR: '7', USD: '5' } }, 'USD')).toEqual([
      { amount: '5', currency: 'USD' },
      { amount: '7', currency: 'EUR' },
    ])
  })

  it('lets the amounts hash override the legacy amount for the same currency', () => {
    expect(listedAmounts({ amount: '5', amounts: { USD: '6', EUR: '7' } }, 'USD')).toEqual([
      { amount: '6', currency: 'USD' },
      { amount: '7', currency: 'EUR' },
    ])
  })

  it('ignores blank hash entries so an emptied currency is not offered', () => {
    expect(listedAmounts({ amounts: { EUR: '', GBP: '8' } }, 'USD')).toEqual([
      { amount: '8', currency: 'GBP' },
    ])
  })
})

describe('amountForCurrency', () => {
  it('puts a pre-6.0 euro amount in the euro row, not the store default', () => {
    const preferences = { amount: '7', currency: 'EUR' }
    expect(amountForCurrency(preferences, 'EUR', 'USD')).toBe('7')
    expect(amountForCurrency(preferences, 'USD', 'USD')).toBeNull()
  })

  it('reads only the amounts hash once it holds an amount, so the single amount is not a price', () => {
    const preferences = { amount: '0', amounts: { EUR: '11' } }
    expect(amountForCurrency(preferences, 'EUR', 'USD')).toBe('11')
    expect(amountForCurrency(preferences, 'USD', 'USD')).toBeNull()
  })

  it('treats a blank currency preference as the store default', () => {
    expect(amountForCurrency({ amount: '5' }, 'USD', 'USD')).toBe('5')
    expect(amountForCurrency({ amount: '5' }, 'EUR', 'USD')).toBeNull()
  })

  it('trims surrounding space on the legacy currency preference', () => {
    const preferences = { amount: '7', currency: ' EUR ' }
    expect(amountForCurrency(preferences, 'EUR', 'USD')).toBe('7')
    expect(amountForCurrency(preferences, 'USD', 'USD')).toBeNull()
  })

  it('reads a lowercase amounts-hash key as that currency', () => {
    expect(amountForCurrency({ amounts: { eur: '7' } }, 'EUR', 'USD')).toBe('7')
  })
})

describe('applyCurrencyAmount', () => {
  it('moves a pre-6.0 euro price into the hash when the dollar row is edited', () => {
    expect(applyCurrencyAmount({ amount: '7', currency: 'EUR' }, 'USD', '10', 'USD')).toEqual({
      amount: null,
      currency: 'EUR',
      amounts: { EUR: '7', USD: '10' },
    })
  })

  it('updates the named currency of a pre-6.0 method in the hash', () => {
    expect(applyCurrencyAmount({ amount: '7', currency: 'EUR' }, 'EUR', '11', 'USD')).toEqual({
      amount: null,
      currency: 'EUR',
      amounts: { EUR: '11' },
    })
  })

  it('writes the store default into the hash like every other currency', () => {
    expect(applyCurrencyAmount({ amount: '5', currency: 'USD' }, 'EUR', '11', 'USD')).toEqual({
      amount: null,
      currency: 'USD',
      amounts: { USD: '5', EUR: '11' },
    })
    expect(applyCurrencyAmount({ amount: null }, 'USD', '9.99', 'USD')).toEqual({
      amount: null,
      amounts: { USD: '9.99' },
    })
  })

  it('removes a cleared currency, the store default included, so the method is not offered in it', () => {
    expect(applyCurrencyAmount({ amounts: { USD: '5', EUR: '7' } }, 'USD', '', 'USD')).toEqual({
      amount: null,
      amounts: { EUR: '7' },
    })
  })

  it('updates and clears a lowercase stored hash key without leaving a stale entry', () => {
    expect(applyCurrencyAmount({ amounts: { eur: '7' } }, 'EUR', '11', 'USD')).toEqual({
      amount: null,
      amounts: { EUR: '11' },
    })
    expect(applyCurrencyAmount({ amounts: { eur: '7' } }, 'EUR', '', 'USD')).toEqual({
      amount: null,
      amounts: {},
    })
  })
})

describe('hasCurrencyAmount', () => {
  it('is true for an amount in the hash or a pre-6.0 single amount', () => {
    expect(hasCurrencyAmount({ amounts: { EUR: '0' } })).toBe(true)
    expect(hasCurrencyAmount({ amount: '5', amounts: {} })).toBe(true)
  })

  it('is false when no currency has an amount', () => {
    expect(hasCurrencyAmount({ amount: null, amounts: { EUR: '' } })).toBe(false)
    expect(hasCurrencyAmount({})).toBe(false)
  })
})
