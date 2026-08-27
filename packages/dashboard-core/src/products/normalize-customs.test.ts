import { describe, expect, it } from 'vitest'
import { normalizeCustomsDescription, normalizeHsCode } from './normalize-customs'

describe('normalizeHsCode', () => {
  it('keeps a plain code unchanged', () => {
    expect(normalizeHsCode('640411')).toBe('640411')
  })

  it('strips separators a broker spreadsheet would carry', () => {
    expect(normalizeHsCode('6404.11')).toBe('640411')
    expect(normalizeHsCode('6404 11')).toBe('640411')
    expect(normalizeHsCode('6404-11-00')).toBe('64041100')
  })

  it('collapses an empty or symbol-only value to null', () => {
    expect(normalizeHsCode('')).toBeNull()
    expect(normalizeHsCode('   ')).toBeNull()
    expect(normalizeHsCode('..')).toBeNull()
    expect(normalizeHsCode(null)).toBeNull()
    expect(normalizeHsCode(undefined)).toBeNull()
  })

  it('does not pad or truncate — the server owns length validation', () => {
    expect(normalizeHsCode('123')).toBe('123')
  })
})

describe('normalizeCustomsDescription', () => {
  it('trims surrounding whitespace', () => {
    expect(normalizeCustomsDescription('  Leather footwear  ')).toBe('Leather footwear')
  })

  it('collapses a blank value to null so clearing the field clears it', () => {
    expect(normalizeCustomsDescription('')).toBeNull()
    expect(normalizeCustomsDescription('   ')).toBeNull()
    expect(normalizeCustomsDescription(null)).toBeNull()
    expect(normalizeCustomsDescription(undefined)).toBeNull()
  })
})
