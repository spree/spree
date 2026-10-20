import type { Market } from '@spree/admin-sdk'
import { describe, expect, it } from 'vitest'
import { marketLocalization } from './store-config'

function market(attributes: Partial<Market>): Market {
  return {
    id: 'mkt_1',
    name: 'Market',
    currency: 'USD',
    default_locale: 'en',
    tax_inclusive: false,
    default: false,
    country_codes: [],
    supported_locales: [],
    created_at: '',
    updated_at: '',
    tax_provider: null,
    ...attributes,
  } as Market
}

describe('marketLocalization', () => {
  const markets = [
    market({
      id: 'mkt_eu',
      currency: 'EUR',
      default_locale: 'de',
      supported_locales: ['de', 'fr'],
    }),
    market({ id: 'mkt_us', currency: 'USD', default_locale: 'en', default: true }),
    market({ id: 'mkt_ie', currency: 'EUR', default_locale: 'en' }),
  ]

  it('takes the defaults from the default market', () => {
    const { defaultCurrency, defaultLocale } = marketLocalization(markets)

    expect(defaultCurrency).toBe('USD')
    expect(defaultLocale).toBe('en')
  })

  it('lists each market currency once, the default market first', () => {
    expect(marketLocalization(markets).currencies).toEqual(['USD', 'EUR'])
  })

  it('lists every language any market offers', () => {
    expect(marketLocalization(markets).locales).toEqual(['de', 'en', 'fr'])
  })

  it('falls back to the first market when none is flagged default', () => {
    const { defaultCurrency } = marketLocalization([market({ currency: 'GBP' })])

    expect(defaultCurrency).toBe('GBP')
  })

  it('returns empty lists before markets load', () => {
    expect(marketLocalization([])).toEqual({
      currencies: [],
      locales: [],
      defaultCurrency: undefined,
      defaultLocale: undefined,
    })
  })
})
