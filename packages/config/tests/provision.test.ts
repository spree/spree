import { describe, expect, it } from 'vitest'
import { planConfig, planOperations, provisionStore, storeDefaults } from '../src/index'
import { FakeApi } from './fake-api'

function polishStore(api: FakeApi) {
  api.store = {
    ...api.store,
    default_country_code: 'PL',
    default_currency: 'PLN',
    preferred_unit_system: 'metric',
    preferred_weight_unit: 'kg',
  }
  api.seed('/countries', [
    { id: 'PL', iso: 'PL', name: 'Poland' },
    { id: 'DE', iso: 'DE', name: 'Germany' },
    { id: 'US', iso: 'US', name: 'United States' },
  ])
  api.seed(
    '/seller_requirements/types',
    [
      'accept_terms',
      'complete_profile',
      'billing_address',
      'returns_address',
      'delivery_method',
      'package_type',
      'minimum_products',
    ].map((type) => ({ type })),
  )
  api.seed('/payment_methods/types', [{ type: 'store_credit' }, { type: 'check' }])
  // Created with the store itself.
  api.seed('/delivery_profiles', [{ name: 'General', kind: 'shipping', default: true }])
  api.seed('/channels', [{ code: 'online', name: 'Online Store' }])
}

describe('storeDefaults', () => {
  it("fills the templates in for the store's country, currency and units", async () => {
    const api = new FakeApi()
    polishStore(api)

    const config = await storeDefaults(api)

    const zones = Object.fromEntries((config.delivery_zones ?? []).map((zone) => [zone.name, zone]))
    expect(zones.Domestic).toMatchObject({ description: 'Poland', countries: ['PL'] })
    expect(zones.International).toMatchObject({ all_countries_except: ['PL'] })
    expect(config.stock_locations?.[0]).toMatchObject({ country_code: 'PL', default: true })
    expect(config.package_types?.[0]).toMatchObject({
      length: 30,
      dimensions_unit: 'cm',
      weight: 0.23,
      weight_unit: 'kg',
    })
    const digital = config.delivery_methods?.find((method) => method.name === 'Digital Delivery')
    expect(digital?.calculator?.preferences).toEqual({ currency: 'PLN' })
    // Both files land in one config, so one deploy orders every section.
    expect(config.delivery_methods?.map((method) => method.name)).toEqual([
      'Digital Delivery',
      'Standard',
      'International Shipping',
      'Store Pickup',
    ])
  })

  it('leaves the country-shaped defaults out on request', async () => {
    const api = new FakeApi()
    polishStore(api)

    const config = await storeDefaults(api, { country: false })

    expect(config.stock_locations).toBeUndefined()
    expect(config.delivery_zones).toBeUndefined()
    expect(config.tax_categories?.map((category) => category.name)).toEqual([
      'Default',
      'Non-taxable',
    ])
  })

  it('refuses a store that has not been placed in a country', async () => {
    const api = new FakeApi()
    api.store = { ...api.store, default_country_code: null }

    await expect(storeDefaults(api)).rejects.toThrow(/finish first-run setup/)
  })
})

describe('provisionStore', () => {
  it('creates every default once and nothing on a second run', async () => {
    const api = new FakeApi()
    polishStore(api)

    const report = await provisionStore(api)
    expect(report.results.filter((result) => result.status === 'failed')).toEqual([])

    const domestic = api.all('/delivery_zones').find((zone) => zone.name === 'Domestic')
    expect(domestic?.delivery_profile_id).toBe(api.all('/delivery_profiles')[0].id)
    const international = api.all('/delivery_zones').find((zone) => zone.name === 'International')
    expect(
      (international?.members as { country_code: string }[]).map((m) => m.country_code),
    ).toEqual(['DE', 'US'])
    const key = api.all('/api_keys')[0]
    expect(key).toMatchObject({ name: 'Storefront (Wholesale)', key_type: 'publishable' })
    expect(key.channel_id).toBe(api.all('/channels').find((c) => c.code === 'wholesale')?.id)

    const again = await planConfig(await storeDefaults(api), api)
    const writes = planOperations(again).filter((operation) =>
      ['create', 'delete'].includes(operation.kind),
    )
    expect(writes).toEqual([])
  })

  it('never changes a default the merchant has edited', async () => {
    const api = new FakeApi()
    polishStore(api)
    await provisionStore(api)
    const standard = api.all('/delivery_methods').find((method) => method.name === 'Standard')
    if (!standard) throw new Error('Standard was not created')
    standard.calculator_preferences = { amount: '7.5', currency: 'PLN' }

    await provisionStore(api)

    expect(api.calls.filter((call) => call.method === 'PATCH')).toEqual([])
    expect(standard.calculator_preferences).toEqual({ amount: '7.5', currency: 'PLN' })
  })

  it('skips kinds the installation has not registered rather than failing on them', async () => {
    const api = new FakeApi()
    polishStore(api)
    api.seed('/seller_requirements/types', [{ type: 'accept_terms' }])
    api.seed('/payment_methods/types', [{ type: 'check' }])

    const report = await provisionStore(api)

    expect(report.results.every((result) => result.status === 'applied')).toBe(true)
    expect(api.all('/seller_requirements').map((requirement) => requirement.type)).toEqual([
      'accept_terms',
    ])
    expect(api.all('/payment_methods')).toEqual([])
  })

  // The store reads the default warehouse as "provisioned", and sample data
  // waits for it, so it must be the last thing created.
  it('creates the default warehouse after everything else', async () => {
    const api = new FakeApi()
    polishStore(api)

    await provisionStore(api)

    const creates = api.calls.filter((call) => call.method === 'POST').map((call) => call.path)
    expect(creates.at(-1)).toBe('/stock_locations')
  })

  it('still creates the warehouse, last, when another default fails', async () => {
    const api = new FakeApi()
    polishStore(api)
    const original = api.request
    api.request = async (method, path, options) => {
      if (method === 'POST' && path === '/allowed_origins') throw new Error('refused')
      return original(method, path, options)
    }

    const report = await provisionStore(api)

    expect(report.results.filter((result) => result.status === 'failed')).toHaveLength(1)
    const creates = api.calls.filter((call) => call.method === 'POST').map((call) => call.path)
    expect(creates.at(-1)).toBe('/stock_locations')
  })

  // Matching is by name, so a renamed default would otherwise come back as a
  // second one and take the default flag.
  it('leaves out a default the store already has another of', async () => {
    const api = new FakeApi()
    polishStore(api)
    api.seed('/tax_categories', [{ name: 'Standard rate', is_default: true }])
    api.seed('/package_types', [{ name: 'Our box', kind: 'box', default: true }])

    await provisionStore(api)

    expect(api.all('/tax_categories').map((category) => category.name)).toEqual([
      'Standard rate',
      'Non-taxable',
    ])
    expect(api.all('/package_types').map((box) => box.name)).toEqual(['Our box'])
  })
})
