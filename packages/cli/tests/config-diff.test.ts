import { describe, expect, it } from 'vitest'
import { diffAttributes, valuesEqual } from '../src/config/index'

describe('valuesEqual', () => {
  it('bridges a number in the file against a numeric string from the API', () => {
    expect(valuesEqual(19.99, '19.99')).toBe(true)
    expect(valuesEqual(12, '12.0')).toBe(true)
    expect(valuesEqual(12, '12.5')).toBe(false)
  })

  it('never coerces two strings, so codes and postcodes keep their zeros', () => {
    expect(valuesEqual('02134', '2134')).toBe(false)
    expect(valuesEqual('007', '7')).toBe(false)
    expect(valuesEqual('1e3', '1000')).toBe(false)
    expect(diffAttributes({ sku: '007' }, { sku: '7' })).toHaveLength(1)
  })

  it('treats a list of scalars as a set', () => {
    expect(valuesEqual(['DE', 'FR'], ['FR', 'DE'])).toBe(true)
    expect(valuesEqual(['DE'], ['DE', 'FR'])).toBe(false)
  })

  it('compares only the attributes the file sets, undefined as null', () => {
    expect(
      diffAttributes({ name: 'A', note: undefined }, { name: 'A', note: 'x', extra: 1 }),
    ).toEqual([])
    expect(diffAttributes({ note: null }, { note: undefined })).toEqual([])
  })
})
