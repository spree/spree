import { describe, expect, it } from 'vitest'
import { CountryCode, CurrencyCode, LocaleCode } from '../src'

describe('ISO code lists', () => {
  it('name each code by its standard value', () => {
    expect(CountryCode.US).toBe('US')
    expect(CurrencyCode.EUR).toBe('EUR')
    expect(LocaleCode.pt_BR).toBe('pt-BR')
  })
})
