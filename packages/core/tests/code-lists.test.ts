import { describe, expect, it } from 'vitest'
import { CountryCode, CurrencyCode, DimensionUnit, LocaleCode, WeightUnit } from '../src'

describe('code lists', () => {
  it('name each code by its standard value', () => {
    expect(CountryCode.US).toBe('US')
    expect(CurrencyCode.EUR).toBe('EUR')
    expect(LocaleCode.pt_BR).toBe('pt-BR')
    expect(WeightUnit.kg).toBe('kg')
    expect(DimensionUnit.ft).toBe('ft')
  })
})
