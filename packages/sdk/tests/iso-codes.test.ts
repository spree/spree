import { describe, expect, it } from 'vitest'
import {
  CountryCode,
  CurrencyCode,
  isCountryCode,
  isCurrencyCode,
  isLocaleCode,
  LocaleCode,
} from '../src'

describe('ISO code lists', () => {
  it('name each code by its standard value', () => {
    expect(CountryCode.US).toBe('US')
    expect(CurrencyCode.EUR).toBe('EUR')
    expect(LocaleCode.pt_BR).toBe('pt-BR')
  })

  it('recognise only listed codes', () => {
    expect(isCountryCode('DE')).toBe(true)
    expect(isCountryCode('ZZ')).toBe(false)
    expect(isCountryCode('de')).toBe(false)
    expect(isCurrencyCode('JPY')).toBe(true)
    expect(isCurrencyCode('XYZ')).toBe(false)
    expect(isLocaleCode('es-419')).toBe(true)
    expect(isLocaleCode('es_419')).toBe(false)
    expect(isLocaleCode(null)).toBe(false)
  })
})
