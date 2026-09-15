import { describe, expect, it } from 'vitest'
import {
  applyPlan,
  deployConfig,
  introspect,
  missingScopes,
  parseConfig,
  planConfig,
  planHasErrors,
  planOperations,
  planToJson,
  renderPlan,
  reportHasFailures,
} from '../src/config/index'
import { FakeApi } from './config-fake-api'

type Payload = Record<string, unknown>

function kinds(plan: {
  sections: { section: string; operations: { key: string; kind: string }[] }[]
}) {
  return Object.fromEntries(
    plan.sections.flatMap((section) =>
      section.operations.map((operation) => [
        `${section.section}/${operation.key}`,
        operation.kind,
      ]),
    ),
  )
}

describe('planConfig', () => {
  it('classifies entries as create, update or unchanged against the live store', async () => {
    const api = new FakeApi()
    api.seed('/channels', [
      { code: 'online', name: 'Online', active: true },
      { code: 'wholesale', name: 'Wholesale', active: true },
    ])
    const { config } = parseConfig(`
version: 1
channels:
  - code: online
    name: Online
  - code: wholesale
    name: Trade
  - code: retail
    name: Retail
`)
    const plan = await planConfig(config, api)
    expect(kinds(plan)).toEqual({
      'channels/online': 'unchanged',
      'channels/wholesale': 'update',
      'channels/retail': 'create',
    })
    const update = planOperations(plan).find((operation) => operation.key === 'wholesale')
    expect(update?.changes).toEqual([{ attribute: 'name', from: 'Wholesale', to: 'Trade' }])
    // Only the declared codes were fetched, not the whole collection.
    expect(api.calls[0].params?.['q[code_in][]']).toEqual(['online', 'wholesale', 'retail'])
  })

  it('compares only what the file sets, treating numeric strings as numbers', async () => {
    const api = new FakeApi()
    api.seed('/tax_categories', [
      { name: 'Default', tax_code: 'A_GEN', is_default: true, description: 'x' },
    ])
    const { config } = parseConfig(
      'version: 1\ntax_categories:\n  - name: Default\n    default: true\n',
    )
    const plan = await planConfig(config, api)
    expect(kinds(plan)).toEqual({ 'tax_categories/Default': 'unchanged' })
  })

  it('deletes live records absent from the file only in pruned sections, and lists the rest as unmanaged', async () => {
    const api = new FakeApi()
    api.seed('/customer_groups', [{ name: 'Wholesale' }, { name: 'VIP' }])
    api.seed('/tax_categories', [{ name: 'Default' }, { name: 'Food' }])
    const { config } = parseConfig(`
version: 1
customer_groups:
  - name: Wholesale
tax_categories:
  - name: Default
`)
    const plan = await planConfig(config, api, { prune: ['customer_groups'] })
    expect(kinds(plan)).toEqual({
      'customer_groups/Wholesale': 'unchanged',
      'customer_groups/VIP': 'delete',
      'tax_categories/Default': 'unchanged',
    })
    expect(renderPlan(plan)).toContain('- VIP')
  })

  it('refuses a key shared by several live records and a duplicate in the file', async () => {
    const api = new FakeApi()
    api.seed('/customer_groups', [{ name: 'Wholesale' }, { name: 'Wholesale' }])
    const { config } = parseConfig(`
version: 1
customer_groups:
  - name: Wholesale
  - name: VIP
  - name: VIP
`)
    const plan = await planConfig(config, api)
    expect(planHasErrors(plan)).toBe(true)
    const errors = planOperations(plan).filter((operation) => operation.kind === 'error')
    expect(errors.map((operation) => operation.message)).toEqual([
      expect.stringMatching(/"VIP" appears more than once/),
      expect.stringMatching(/2 live records share name "Wholesale"/),
    ])
  })

  it('resolves references to live records and to records the file creates, and reports dangling ones', async () => {
    const api = new FakeApi()
    api.seed('/delivery_zones', [{ name: 'Domestic' }])
    api.seed('/stock_locations', [])
    const { config } = parseConfig(`
version: 1
delivery_zones:
  - name: Europe
    countries: [DE, FR]
delivery_methods:
  - name: Standard
    delivery_zone: Domestic
  - name: Standard EU
    delivery_zone: Europe
    calculator: { type: flat_rate, preferences: { amount: 9.9, currency: EUR } }
  - name: Broken
    delivery_zone: Mars
`)
    const plan = await planConfig(config, api)
    const operations = planOperations(plan)
    const standard = operations.find((operation) => operation.key === 'Standard') as {
      payload: Record<string, unknown>
    }
    expect(standard.payload.delivery_zone_id).toBe(api.all('/delivery_zones')[0].id)
    const europe = operations.find((operation) => operation.key === 'Standard EU') as {
      payload: Record<string, unknown>
    }
    expect(europe.payload.delivery_zone_id).toMatchObject({
      section: 'delivery_zones',
      key: 'Europe',
    })
    expect(europe.payload.calculator_type).toBe('flat_rate')
    const broken = operations.find((operation) => operation.key === 'Broken')
    expect(broken?.kind).toBe('error')
    expect(broken?.message).toMatch(
      /delivery_zones "Mars" is not declared in the file and does not exist/,
    )
    expect(broken?.path).toBe('delivery_methods[2]')
  })

  it('plans the store singleton as an update of its preferences', async () => {
    const api = new FakeApi()
    const { config } = parseConfig(
      'version: 1\nstore:\n  name: Acme\n  preferences: { guest_checkout: false }\n',
    )
    const plan = await planConfig(config, api)
    expect(kinds(plan)).toEqual({ 'store/store': 'update' })
    expect(planOperations(plan)[0].changes).toEqual([
      { attribute: 'name', from: 'Shop', to: 'Acme' },
      { attribute: 'preferred_guest_checkout', from: true, to: false },
    ])
  })

  it('strips live records and payloads from the JSON form', async () => {
    const api = new FakeApi()
    api.seed('/channels', [{ code: 'online', name: 'Online' }])
    const { config } = parseConfig('version: 1\nchannels:\n  - code: online\n    name: Web\n')
    const json = planToJson(await planConfig(config, api))
    expect(json.sections[0].operations[0]).toEqual({
      section: 'channels',
      kind: 'update',
      key: 'online',
      path: 'channels[0]',
      changes: [{ attribute: 'name', from: 'Online', to: 'Web' }],
    })
  })
})

describe('applyPlan', () => {
  it('creates in dependency order, resolving references to records created in the same run', async () => {
    const api = new FakeApi()
    api.seed('/delivery_zones', [])
    api.seed('/delivery_methods', [])
    const { config } = parseConfig(`
version: 1
delivery_zones:
  - name: Europe
    countries: [DE]
delivery_methods:
  - name: Standard EU
    delivery_zone: Europe
`)
    const report = await deployConfig(config, api)
    expect(report.results.map((result) => result.status)).toEqual(['applied', 'applied'])
    const zone = api.all('/delivery_zones')[0]
    expect(zone.members).toEqual([{ member_type: 'country', country_code: 'DE', state_code: null }])
    expect(api.all('/delivery_methods')[0].delivery_zone_id).toBe(zone.id)
  })

  it('reports a failed write against its file path and carries on with the rest', async () => {
    const api = new FakeApi()
    api.seed('/customer_groups', [])
    const original = api.request
    api.request = async (method, path, options) => {
      if (method === 'POST' && (options?.body as { name: string }).name === 'Bad') {
        const error = new Error('Validation failed') as Error & { status: number; details: unknown }
        error.status = 422
        error.details = { name: [{ code: 'taken', message: 'has already been taken' }] }
        throw error
      }
      return original(method, path, options)
    }
    const { config } = parseConfig('version: 1\ncustomer_groups:\n  - name: Bad\n  - name: Good\n')
    const report = await deployConfig(config, api)
    expect(report.results.map((result) => [result.operation.path, result.status])).toEqual([
      ['customer_groups[0]', 'failed'],
      ['customer_groups[1]', 'applied'],
    ])
    expect(report.results[0].message).toBe('HTTP 422: Validation failed')
    expect(report.results[0].details).toEqual({
      name: [{ code: 'taken', message: 'has already been taken' }],
    })
  })

  it('deletes pruned records after every write, and never writes plan errors', async () => {
    const api = new FakeApi()
    api.seed('/customer_groups', [{ name: 'Old' }])
    const { config } = parseConfig('version: 1\ncustomer_groups:\n  - name: New\n')
    const run = await planConfig(config, api, { prune: ['customer_groups'] })
    const report = await applyPlan(run)
    expect(report.results.map((result) => [result.operation.kind, result.status])).toEqual([
      ['create', 'applied'],
      ['delete', 'applied'],
    ])
    expect(api.all('/customer_groups').map((group) => group.name)).toEqual(['New'])
  })

  it('creates a product with its variant, prices and stock, publishes it, and is idempotent', async () => {
    const api = new FakeApi()
    api.seed('/stock_locations', [{ name: 'Warehouse' }])
    api.seed('/channels', [{ code: 'online', name: 'Online' }])
    api.seed('/categories', [{ permalink: 'tees', name: 'Tees' }])
    api.seed('/products', [])
    const { config } = parseConfig(`
version: 1
products:
  - slug: classic-tee
    name: Classic Tee
    status: active
    categories: [tees]
    channels: [online]
    sku: TEE
    prices: { USD: 29.99 }
    stock: { Warehouse: 100 }
`)
    const first = await deployConfig(config, api)
    expect(first.results.map((result) => result.status)).toEqual(['applied'])
    const product = api.all('/products')[0]
    expect(product.slug).toBe('classic-tee')
    expect((product.variants as { sku: string }[]).map((variant) => variant.sku)).toEqual(['TEE'])
    expect(product.product_publications).toEqual([
      { channel_id: api.all('/channels')[0].id, unpublished_at: null },
    ])
    const create = api.calls.find((call) => call.method === 'POST' && call.path === '/products')
    expect(create?.body).toMatchObject({
      variants: [
        {
          sku: 'TEE',
          prices: [{ currency: 'USD', amount: 29.99 }],
          stock_levels: [
            { stock_location_id: api.all('/stock_locations')[0].id, count_on_hand: 100 },
          ],
        },
      ],
    })

    const again = await planConfig(config, api)
    expect(kinds(again)).toEqual({ 'products/classic-tee': 'unchanged' })
  })

  it('updates a product variant in place by SKU and removes it from a channel', async () => {
    const api = new FakeApi()
    api.seed('/channels', [
      { code: 'online', name: 'Online' },
      { code: 'b2b', name: 'B2B' },
    ])
    const [online, b2b] = api.all('/channels')
    api.seed('/products', [
      {
        slug: 'tee',
        name: 'Tee',
        status: 'active',
        categories: [],
        product_publications: [
          { channel_id: online.id, unpublished_at: null },
          { channel_id: b2b.id, unpublished_at: null },
        ],
        variants: [
          {
            id: 'variant_9',
            sku: 'TEE-S',
            option_values: [{ option_type_name: 'size', name: 's' }],
            prices: [
              {
                currency: 'USD',
                amount: '10.0',
                compare_at_amount: null,
                price_list_id: null,
                min_quantity: 1,
              },
            ],
            stock_levels: [],
          },
        ],
      },
    ])
    const { config } = parseConfig(`
version: 1
products:
  - slug: tee
    name: Tee
    channels: [online]
    variants:
      - sku: TEE-S
        options: { size: S }
        prices: { USD: 12 }
`)
    const plan = await planConfig(config, api)
    expect(kinds(plan)).toEqual({ 'products/tee': 'update' })
    expect(planOperations(plan)[0].changes?.map((change) => change.attribute)).toEqual([
      'channels',
      'variants',
    ])
    // Option values are stored parameterized (`s`), which is the file's `S`.
    const sameOptions = {
      ...config,
      products: [
        {
          ...config.products?.[0],
          channels: ['online', 'b2b'],
          variants: [{ sku: 'TEE-S', options: { size: 'S' }, prices: { USD: 10 } }],
        },
      ],
    } as typeof config
    expect(kinds(await planConfig(sameOptions, api))).toEqual({ 'products/tee': 'unchanged' })
    await applyPlan(plan)
    const patch = api.calls.find((call) => call.method === 'PATCH')
    expect((patch?.body as { variants: { id: string }[] }).variants[0].id).toBe('variant_9')
    expect(api.all('/products')[0].product_publications).toEqual([
      { channel_id: online.id, unpublished_at: null },
    ])
  })

  it('reports a plan error as a failed result so a scripted deploy stops', async () => {
    const api = new FakeApi()
    api.seed('/stock_locations', [])
    api.seed('/products', [])
    const { config } = parseConfig(`
version: 1
products:
  - slug: tee
    name: Tee
    sku: TEE
    stock: { Nowhere: 1 }
`)
    const report = await deployConfig(config, api)
    expect(reportHasFailures(report)).toBe(true)
    expect(report.results[0]).toMatchObject({
      status: 'failed',
      message: expect.stringMatching(/stock_locations "Nowhere" is not declared/),
    })
    expect(api.all('/products')).toEqual([])
  })

  it('approves a seller through its action once created', async () => {
    const api = new FakeApi()
    api.seed('/sellers', [])
    const { config } = parseConfig(
      'version: 1\nsellers:\n  - slug: acme\n    name: Acme\n    status: approved\n',
    )
    await deployConfig(config, api)
    expect(api.all('/sellers')[0].status).toBe('approved')
    expect(api.calls.some((call) => call.path.endsWith('/approve'))).toBe(true)
  })
})

describe('introspect', () => {
  it('reads the live store back as file entries with references by key', async () => {
    const api = new FakeApi()
    api.seed('/stock_locations', [{ name: 'Warehouse', active: true, default: true }])
    api.seed('/channels', [
      {
        code: 'online',
        name: 'Online',
        active: true,
        default: true,
        stock_location_ids: [],
        preferred_guest_checkout: true,
        created_at: 'x',
      },
    ])
    api.seed('/delivery_zones', [
      {
        name: 'Europe',
        members: [{ member_type: 'country', country_code: 'DE', state_code: null }],
      },
    ])
    api.seed('/delivery_methods', [
      {
        name: 'Standard EU',
        delivery_zone_id: api.all('/delivery_zones')[0].id,
        calculator_type: 'flat_rate',
        calculator_preferences: {
          amount: '9.9',
          currency: 'EUR',
          minimum_item_total: null,
          amounts: {},
        },
      },
    ])
    const config = await introspect(api, {
      include: ['channels', 'delivery_zones', 'delivery_methods'],
    })
    expect(config).toEqual({
      version: 1,
      channels: [
        {
          code: 'online',
          name: 'Online',
          active: true,
          default: true,
          preferences: { guest_checkout: true },
        },
      ],
      delivery_zones: [{ name: 'Europe', countries: ['DE'] }],
      delivery_methods: [
        {
          name: 'Standard EU',
          delivery_zone: 'Europe',
          calculator: { type: 'flat_rate', preferences: { amount: 9.9, currency: 'EUR' } },
        },
      ],
    })
  })
})

describe('missingScopes', () => {
  it('names the write scopes the key lacks, and accepts write_all', async () => {
    const api = new FakeApi()
    api.scopes = ['read_all', 'write_products']
    expect(await missingScopes(api, ['products', 'channels', 'customers'])).toEqual([
      'write_settings',
      'write_customers',
    ])
    api.scopes = ['write_all']
    expect(await missingScopes(api, ['products'])).toEqual([])
    api.scopes = null
    expect(await missingScopes(api, ['products'])).toBeNull()
  })
})

describe('edge cases', () => {
  it('plans an empty section as nothing to do', async () => {
    const api = new FakeApi()
    api.seed('/products', [{ slug: 'left-alone', name: 'Left alone' }])
    const { config } = parseConfig('version: 1\nproducts: []\ncustomers: []\n')
    const plan = await planConfig(config, api)
    expect(plan.sections.map((section) => [section.section, section.operations.length])).toEqual([
      ['products', 0],
      ['customers', 0],
    ])
  })

  it('reports a referenced key shared by several live records as ambiguous', async () => {
    const api = new FakeApi()
    api.seed('/delivery_zones', [{ name: 'Europe' }, { name: 'Europe' }])
    const { config } = parseConfig(
      'version: 1\ndelivery_methods:\n  - name: Standard\n    delivery_zone: Europe\n',
    )
    const plan = await planConfig(config, api)
    expect(planOperations(plan)[0]).toMatchObject({
      kind: 'error',
      path: 'delivery_methods[0]',
      message: expect.stringMatching(/2 live delivery_zones share the key "Europe"/),
    })
  })

  it('lists only first-party rows on tables sellers also write to', async () => {
    const api = new FakeApi()
    api.seed('/stock_locations', [{ name: 'Warehouse' }])
    const { config } = parseConfig('version: 1\nstock_locations:\n  - name: Warehouse\n')
    await planConfig(config, api)
    expect(api.calls[0].params).toMatchObject({ 'q[seller_id_null]': 1 })
  })
})

describe('products', () => {
  it('shows a price and a stock level the file omits as removals, since the write replaces both sets', async () => {
    const api = new FakeApi()
    api.seed('/stock_locations', [{ name: 'Warehouse' }, { name: 'Overflow' }])
    const [warehouse, overflow] = api.all('/stock_locations')
    api.seed('/products', [
      {
        slug: 'tee',
        name: 'Tee',
        categories: [],
        variants: [
          {
            id: 'variant_1',
            sku: 'TEE',
            option_values: [],
            prices: [
              {
                currency: 'USD',
                amount: '10.0',
                compare_at_amount: null,
                price_list_id: null,
                min_quantity: 1,
              },
              {
                currency: 'EUR',
                amount: '9.0',
                compare_at_amount: null,
                price_list_id: null,
                min_quantity: 1,
              },
            ],
            stock_levels: [
              { stock_location_id: warehouse.id, count_on_hand: 5 },
              { stock_location_id: overflow.id, count_on_hand: 7 },
            ],
          },
        ],
      },
    ])
    const { config } = parseConfig(`
version: 1
products:
  - slug: tee
    name: Tee
    sku: TEE
    prices: { USD: 10 }
    stock: { Warehouse: 5 }
`)
    const plan = await planConfig(config, api)
    expect(kinds(plan)).toEqual({ 'products/tee': 'update' })
    const change = planOperations(plan)[0].changes?.find((entry) => entry.attribute === 'variants')
    // The live side still carries EUR and the second warehouse, so the diff
    // shows what the deploy is about to drop.
    expect(JSON.stringify(change?.from)).toMatch(/EUR/)
    expect(JSON.stringify(change?.to)).not.toMatch(/EUR/)
  })

  it('declares a variant for a product that sets only compare-at prices', async () => {
    const api = new FakeApi()
    api.seed('/products', [])
    const { config } = parseConfig(
      'version: 1\nproducts:\n  - slug: tee\n    name: Tee\n    compare_at_prices: { USD: 40 }\n',
    )
    await deployConfig(config, api)
    const create = api.calls.find((call) => call.method === 'POST' && call.path === '/products')
    expect((create?.body as { variants: Payload[] }).variants).toEqual([
      { sku: 'TEE', prices: [{ currency: 'USD', compare_at_amount: 40 }] },
    ])
  })

  it('compares a description the way the API renders it, and writes the markup the file holds', async () => {
    const api = new FakeApi()
    api.seed('/products', [
      { slug: 'tee', name: 'Tee', description: 'Soft cotton', categories: [], variants: [] },
    ])
    const { config } = parseConfig(
      'version: 1\nproducts:\n  - slug: tee\n    name: Tee\n    description: "<p>Soft cotton</p>"\n',
    )
    expect(kinds(await planConfig(config, api))).toEqual({ 'products/tee': 'unchanged' })

    const changed = parseConfig(
      'version: 1\nproducts:\n  - slug: tee\n    name: Tee\n    description: "<p>Heavy cotton</p>"\n',
    ).config
    const plan = await planConfig(changed, api)
    expect(kinds(plan)).toEqual({ 'products/tee': 'update' })
    await applyPlan(plan)
    const patch = api.calls.find(
      (call) => call.method === 'PATCH' && call.path.startsWith('/products/'),
    )
    expect((patch?.body as { description: string }).description).toBe('<p>Heavy cotton</p>')
  })

  it('refuses to approve a seller that has not started onboarding, naming why', async () => {
    const api = new FakeApi()
    api.seed('/sellers', [])
    const { config } = parseConfig(
      'version: 1\nsellers:\n  - slug: acme\n    name: Acme\n    status: approved\n',
    )
    // The fake API creates sellers `pending`, as Spree::Sellers::Create does.
    api.collections.set('/sellers', [])
    const original = api.request
    api.request = async (method, path, options) => {
      const result = await original(method, path, options)
      if (method === 'POST' && path === '/sellers')
        (result as { status?: string }).status = 'pending'
      return result as never
    }
    const report = await deployConfig(config, api)
    expect(report.results[0]).toMatchObject({
      status: 'failed',
      message: expect.stringMatching(/can be approved only once onboarding has started/),
    })
  })
})
