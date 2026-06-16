import { describe, expect, it } from 'vitest'
import { normalizeMoneyInput } from './normalize-money'

describe('normalizeMoneyInput', () => {
  it('passes through canonical en input', () => {
    expect(normalizeMoneyInput('19.99', 'en')).toBe('19.99')
    expect(normalizeMoneyInput('1,234.56', 'en')).toBe('1234.56')
    expect(normalizeMoneyInput('1234.56', 'en')).toBe('1234.56')
  })

  it('converts de comma-decimal + dot grouping to canonical', () => {
    expect(normalizeMoneyInput('19,99', 'de')).toBe('19.99')
    expect(normalizeMoneyInput('1.234,56', 'de')).toBe('1234.56')
    expect(normalizeMoneyInput('1.000.000,00', 'de')).toBe('1000000.00')
  })

  it('handles fr narrow-space grouping', () => {
    // fr groups with U+202F (narrow no-break space) and uses a comma decimal.
    expect(normalizeMoneyInput('1 234,56', 'fr')).toBe('1234.56')
    expect(normalizeMoneyInput('73,45', 'fr')).toBe('73.45')
  })

  it('returns empty string for blank input', () => {
    expect(normalizeMoneyInput('', 'de')).toBe('')
    expect(normalizeMoneyInput('   ', 'de')).toBe('')
    expect(normalizeMoneyInput(null, 'de')).toBe('')
    expect(normalizeMoneyInput(undefined, 'de')).toBe('')
  })

  it('preserves a leading minus', () => {
    expect(normalizeMoneyInput('-5,00', 'de')).toBe('-5.00')
    expect(normalizeMoneyInput('-5.00', 'en')).toBe('-5.00')
  })

  it('drops stray currency symbols and whitespace', () => {
    expect(normalizeMoneyInput(' € 1.234,56 ', 'de')).toBe('1234.56')
    expect(normalizeMoneyInput('$19.99', 'en')).toBe('19.99')
  })

  it('keeps no-decimal values intact', () => {
    expect(normalizeMoneyInput('50', 'de')).toBe('50')
    expect(normalizeMoneyInput('1.000', 'de')).toBe('1000') // de: dot is grouping
    expect(normalizeMoneyInput('1,000', 'en')).toBe('1000') // en: comma is grouping
  })

  it('collapses stray separators to a single decimal point', () => {
    // Malformed multi-dot/interior-minus input must canonicalize, not pass through.
    expect(normalizeMoneyInput('1.2.3', 'en')).toBe('1.23')
    expect(normalizeMoneyInput('12-3.4', 'en')).toBe('123.4')
    expect(normalizeMoneyInput('-12-3.4', 'en')).toBe('-123.4')
  })

  it('returns empty for inputs with no digits', () => {
    expect(normalizeMoneyInput('.', 'en')).toBe('')
    expect(normalizeMoneyInput('-', 'en')).toBe('')
    expect(normalizeMoneyInput('abc', 'en')).toBe('')
  })
})
