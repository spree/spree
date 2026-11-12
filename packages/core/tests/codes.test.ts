import { describe, expect, it } from 'vitest'
import {
  ACTIVE_CURRENCY_CODES,
  CurrencyCode,
  isCountryCode,
  isCurrencyCode,
  isLocaleCode,
  RETIRED_CURRENCY_CODES,
} from '../src'

describe('code shapes', () => {
  it('accepts a code by its shape, including one this package does not list', () => {
    expect([
      isCountryCode('US'),
      isCountryCode('XK'),
      isCountryCode('us'),
      isCountryCode(1),
    ]).toEqual([true, true, false, false])
    expect([isCurrencyCode('EUR'), isCurrencyCode('EU'), isCurrencyCode(null)]).toEqual([
      true,
      false,
      false,
    ])
    expect([
      isLocaleCode('en'),
      isLocaleCode('pt-BR'),
      isLocaleCode('es-419'),
      isLocaleCode('pt_BR'),
    ]).toEqual([true, true, true, false])
  })
})

describe('active currencies', () => {
  it('lists every accepted currency except the retired ones', () => {
    for (const code of RETIRED_CURRENCY_CODES) expect(Object.values(CurrencyCode)).toContain(code)
    expect(ACTIVE_CURRENCY_CODES).toContain('EUR')
    expect(ACTIVE_CURRENCY_CODES).not.toContain('HRK')
    expect(ACTIVE_CURRENCY_CODES.length + RETIRED_CURRENCY_CODES.size).toBe(
      Object.values(CurrencyCode).length,
    )
  })
})
