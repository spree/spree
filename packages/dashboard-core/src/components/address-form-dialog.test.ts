import { describe, expect, it } from 'vitest'
import { resolveAddressCountryCode } from './address-form-dialog'

describe('resolveAddressCountryCode', () => {
  it('keeps the country stored on an existing address', () => {
    expect(resolveAddressCountryCode({ id: 'addr_1', country_code: 'DE' }, 'US')).toBe('DE')
  })

  it('uses the store default when the address has no country', () => {
    expect(resolveAddressCountryCode({ first_name: 'Ada' }, 'US')).toBe('US')
    expect(resolveAddressCountryCode(null, 'PL')).toBe('PL')
    expect(resolveAddressCountryCode(undefined, 'GB')).toBe('GB')
  })

  it('treats a blank stored country as missing', () => {
    expect(resolveAddressCountryCode({ country_code: '' }, 'FR')).toBe('FR')
    expect(resolveAddressCountryCode({ country_code: null }, 'FR')).toBe('FR')
  })

  it('stays empty when neither the address nor the store has a country', () => {
    expect(resolveAddressCountryCode(null, null)).toBe('')
    expect(resolveAddressCountryCode(undefined, undefined)).toBe('')
    expect(resolveAddressCountryCode({ country_code: '' }, '')).toBe('')
  })
})
