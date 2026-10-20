import { describe, expect, it } from 'vitest'
import { intlDisplayName } from '../src'

describe('intlDisplayName', () => {
  it('names a code in the reader’s language', () => {
    expect(intlDisplayName('region', 'en', 'US')).toBe('United States')
    expect(intlDisplayName('currency', 'en', 'EUR')).toBe('Euro')
  })

  it('answers undefined for a malformed code', () => {
    expect(intlDisplayName('language', 'en', 'not a code')).toBeUndefined()
  })
})
