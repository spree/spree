import { describe, expect, it } from 'vitest'
import { normalizeQuantityRule } from './normalize-quantity'

describe('normalizeQuantityRule', () => {
  it('reads a whole number', () => {
    expect(normalizeQuantityRule('48')).toBe(48)
    expect(normalizeQuantityRule(24)).toBe(24)
  })

  // Blank means the rule is unset, which is not zero: an empty minimum lets
  // a buyer take one.
  it('treats a blank field as unset', () => {
    expect(normalizeQuantityRule('')).toBeNull()
    expect(normalizeQuantityRule('   ')).toBeNull()
    expect(normalizeQuantityRule(null)).toBeNull()
    expect(normalizeQuantityRule(undefined)).toBeNull()
  })

  it('rejects values a rule cannot mean', () => {
    expect(normalizeQuantityRule('0')).toBeNull()
    expect(normalizeQuantityRule('-5')).toBeNull()
    expect(normalizeQuantityRule('abc')).toBeNull()
  })

  it('truncates a fractional entry to whole units', () => {
    expect(normalizeQuantityRule('48.9')).toBe(48)
  })
})
