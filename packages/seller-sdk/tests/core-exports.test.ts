import { describe, expect, it } from 'vitest'
import * as sdk from '../src'

// The code lists and money helpers live in @spree/core; clients import them
// from the SDK, so the SDK has to keep offering every one of them.
describe('@spree/core exports', () => {
  it.each([
    'CountryCode',
    'CurrencyCode',
    'DimensionUnit',
    'LocaleCode',
    'WeightUnit',
    'compareMoney',
    'decimalPlaces',
    'formatMoney',
    'isDecimalString',
    'isZeroMoney',
    'multiplyMoney',
    'negateMoney',
    'subtractMoney',
    'sumMoney',
  ])('offers %s', (name) => {
    expect(sdk).toHaveProperty(name)
  })
})
