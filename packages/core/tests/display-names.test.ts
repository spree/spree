import { describe, expect, it } from 'vitest'
import { intlDisplayName, localeEndonym } from '../src'

describe('intlDisplayName', () => {
  it('names a code in the reader’s language', () => {
    expect(intlDisplayName('region', 'en', 'US')).toBe('United States')
    expect(intlDisplayName('currency', 'en', 'EUR')).toBe('Euro')
  })

  it('answers undefined for a malformed code', () => {
    expect(intlDisplayName('language', 'en', 'not a code')).toBeUndefined()
  })
})

describe('localeEndonym', () => {
  it('names a language in itself, capitalized', () => {
    expect(localeEndonym('de')).toBe('Deutsch')
    expect(localeEndonym('fr')).toBe('Français')
  })

  it('answers an unknown code back', () => {
    expect(localeEndonym('not a code')).toBe('not a code')
  })
})
