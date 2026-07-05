import { describe, expect, it } from 'vitest'
import { client } from './helpers'

describe('markets', () => {
  it('lists markets', async () => {
    const result = await client().markets.list()

    expect(result.data.length).toBeGreaterThan(0)
    const market = result.data[0]
    expect(market.id).toMatch(/^mkt_/)
    expect(market).toHaveProperty('name')
    expect(market).toHaveProperty('currency')
  })

  it('resolves market by country', async () => {
    const market = await client().markets.resolve('US')
    expect(market.id).toMatch(/^mkt_/)
  })
})

describe('countries', () => {
  it('lists countries', async () => {
    const result = await client().countries.list()

    expect(result.data.length).toBeGreaterThan(0)
    const country = result.data[0]
    expect(country).toHaveProperty('iso')
    expect(country).toHaveProperty('name')
  })

  it('gets a country with states', async () => {
    const country = await client().countries.get('US', { expand: ['states'] })

    expect(country.iso).toBe('US')
    expect(country.name).toBe('United States')
  })
})
