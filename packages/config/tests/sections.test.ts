import { describe, expect, it } from 'vitest'
import {
  deployConfig,
  introspect,
  parseConfig,
  planConfig,
  planOperations,
  reportHasFailures,
} from '../src/node'
import { FakeApi } from './fake-api'

type Payload = Record<string, unknown>

const MONEY = { type: ['string', 'null'], format: 'money' }

async function unchanged(api: FakeApi, file: string) {
  const plan = await planConfig(parseConfig(file).config, api)
  return planOperations(plan).every((operation) => operation.kind === 'unchanged')
}

const lastBody = (api: FakeApi, method: string, path: RegExp) =>
  api.calls.filter((call) => call.method === method && path.test(call.path)).at(-1)?.body as Payload

describe('option types', () => {
  const FILE = `
version: 1
option_types:
  - name: condition
    label: Condition
    kind: buttons
    values:
      - name: new
        label: New
      - name: used
        label: Used
`

  it('writes values in file order and keeps the ids of the ones already there', async () => {
    const api = new FakeApi()
    api.seed('/option_types', [])
    await deployConfig(parseConfig(FILE).config, api)
    const [type] = api.all('/option_types')
    const [fresh, used] = type.option_values as Payload[]
    expect([fresh.position, used.position]).toEqual([1, 2])
    expect(await unchanged(api, FILE)).toBe(true)

    // A value added in front: the two existing ones are sent with their ids,
    // so variants holding them keep them.
    const edited = FILE.replace('      - name: new', '      - name: refurbished\n      - name: new')
    await deployConfig(parseConfig(edited).config, api)
    expect(lastBody(api, 'PATCH', /option_types/).option_values).toEqual([
      { name: 'refurbished', position: 1 },
      { id: fresh.id, name: 'new', label: 'New', position: 2 },
      { id: used.id, name: 'used', label: 'Used', position: 3 },
    ])
    const captured = await introspect(api, { include: ['option_types'] })
    expect(captured.option_types?.[0].values?.map((value) => value.name)).toEqual([
      'refurbished',
      'new',
      'used',
    ])
  })
})

describe('product types', () => {
  it('links option types, categories and the custom fields its products show', async () => {
    const api = new FakeApi()
    for (const path of [
      '/option_types',
      '/custom_field_definitions',
      '/categories',
      '/product_types',
    ])
      api.seed(path, [])
    const file = `
version: 1
option_types:
  - name: color
    label: Color
custom_field_definitions:
  - { resource_type: product, key: wattage, field_type: short_text }
  - { resource_type: product, key: capacity, field_type: short_text }
categories:
  - permalink: kitchen
    name: Kitchen
product_types:
  - name: Kitchen Appliance
    option_types: [color]
    categories: [kitchen]
    custom_fields:
      - key: wattage
        required: true
      - key: capacity
`
    const report = await deployConfig(parseConfig(file).config, api)
    expect(reportHasFailures(report)).toBe(false)
    const [type] = api.all('/product_types')
    const [wattage, capacity] = api.all('/custom_field_definitions')
    expect(type).toMatchObject({
      option_type_ids: [api.all('/option_types')[0].id],
      category_ids: [api.all('/categories')[0].id],
      custom_field_definitions: [
        { id: wattage.id, required: true, sort_order: 0 },
        { id: capacity.id, required: false, sort_order: 1 },
      ],
    })
    expect(await unchanged(api, file)).toBe(true)
    const captured = await introspect(api, { include: ['product_types'] })
    expect(captured.product_types?.[0]).toEqual({
      name: 'Kitchen Appliance',
      option_types: ['color'],
      categories: ['kitchen'],
      custom_fields: [{ key: 'wattage', required: true }, { key: 'capacity' }],
    })
  })
})

describe('rules', () => {
  it('sends an amount as a decimal string and reads it back as a number', async () => {
    const api = new FakeApi()
    api.kinds['/delivery_method_rules/types'] = [
      { type: 'item_total_rule', schema: { properties: { minimum_amount: MONEY } } },
    ]
    api.seed('/delivery_methods', [])
    const file = `
version: 1
delivery_methods:
  - name: Free over 100
    rules:
      - type: item_total_rule
        preferences: { minimum_amount: 100 }
`
    await deployConfig(parseConfig(file).config, api)
    const [method] = api.all('/delivery_methods')
    expect(method.rules).toEqual([
      { type: 'item_total_rule', preferences: { minimum_amount: '100' } },
    ])
    ;(method.rules as Payload[])[0].preferences = { minimum_amount: '100.0', maximum_amount: null }
    expect(await unchanged(api, file)).toBe(true)
    const captured = await introspect(api, { include: ['delivery_methods'] })
    expect(captured.delivery_methods?.[0].rules).toEqual([
      { type: 'item_total_rule', preferences: { minimum_amount: 100 } },
    ])
  })

  it('writes a setting that lists records as their natural keys', async () => {
    const api = new FakeApi()
    api.kinds['/price_lists/price_rule_types'] = [
      {
        type: 'customer_group_rule',
        schema: {
          properties: { customer_group_ids: { type: 'array', items: { 'x-spree-prefix': 'cg' } } },
        },
      },
      { type: 'volume_rule', schema: { properties: { min_quantity: { type: 'integer' } } } },
    ]
    api.seed('/customer_groups', [])
    api.seed('/price_lists', [])
    const file = `
version: 1
customer_groups:
  - name: Trade
price_lists:
  - name: Trade prices
    active: true
    rules:
      - type: volume_rule
        preferences: { min_quantity: 10 }
      - type: customer_group_rule
        preferences: { customer_group_ids: [Trade] }
`
    const report = await deployConfig(parseConfig(file).config, api)
    expect(reportHasFailures(report)).toBe(false)
    const [list] = api.all('/price_lists')
    const [group] = api.all('/customer_groups')
    expect(list.status).toBe('active')
    expect((list.price_rules as Payload[]).map((rule) => rule.preferences)).toEqual([
      { customer_group_ids: [group.id] },
      { min_quantity: 10 },
    ])
    expect(await unchanged(api, file)).toBe(true)
    const captured = await introspect(api, { include: ['price_lists'] })
    expect(captured.price_lists?.[0]).toEqual({
      name: 'Trade prices',
      active: true,
      rules: [
        { type: 'customer_group_rule', preferences: { customer_group_ids: ['Trade'] } },
        { type: 'volume_rule', preferences: { min_quantity: 10 } },
      ],
    })
  })
})

describe('collections', () => {
  it('holds exactly the products a curated collection lists', async () => {
    const api = new FakeApi()
    api.seed('/products', [
      { id: 'prod_1', slug: 'kettle', name: 'Kettle' },
      { id: 'prod_2', slug: 'toaster', name: 'Toaster' },
      { id: 'prod_3', slug: 'blender', name: 'Blender' },
    ])
    api.seed('/collections', [])
    const file = (products: string) => `
version: 1
collections:
  - permalink: best-sellers
    name: Best Sellers
    sort_order: best_selling
    products: [${products}]
`
    await deployConfig(parseConfig(file('kettle, toaster')).config, api)
    const [collection] = api.all('/collections')
    expect(api.members.get(`/collections/${collection.id}`)).toEqual(['prod_1', 'prod_2'])
    expect(collection.products).toBeUndefined()
    expect(await unchanged(api, file('kettle, toaster'))).toBe(true)

    await deployConfig(parseConfig(file('toaster, blender')).config, api)
    expect(api.members.get(`/collections/${collection.id}`)).toEqual(['prod_2', 'prod_3'])
  })

  it('compares the rules of an automatic collection and refuses a product list on one', async () => {
    const api = new FakeApi()
    api.seed('/collections', [
      {
        permalink: 'on-sale',
        name: 'On Sale',
        automatic: true,
        rules: [{ id: 'crule_1', type: 'sale', value: 'true', match_policy: 'is_equal_to' }],
      },
    ])
    const file = `
version: 1
collections:
  - permalink: on-sale
    name: On Sale
    automatic: true
    rules:
      - { type: sale, value: "true", match_policy: is_equal_to }
`
    expect(await unchanged(api, file)).toBe(true)
    expect(() => parseConfig(`${file}    products: [kettle]\n`)).toThrow(
      /takes its products from `rules`/,
    )
  })
})

describe('promotions', () => {
  it('replaces the action of a kind in place, since a promotion holds one of each', async () => {
    const api = new FakeApi()
    api.kinds['/promotion_actions/types'] = [
      { type: 'create_adjustment' },
      { type: 'free_shipping' },
    ]
    api.kinds['/promotion_actions/calculators?type=create_adjustment'] = [
      { type: 'flat_rate', schema: { properties: { amount: MONEY } } },
    ]
    api.seed('/promotions', [])
    const file = (amount: number) => `
version: 1
promotions:
  - name: Ten Off
    code: TENOFF
    actions:
      - type: create_adjustment
        calculator:
          type: flat_rate
          preferences: { amount: ${amount}, currency: USD }
`
    await deployConfig(parseConfig(file(10)).config, api)
    const [promotion] = api.all('/promotions')
    // Codes are saved in lower case.
    expect(promotion.code).toBe('tenoff')
    const [action] = promotion.actions as Payload[]
    expect(action.calculator).toEqual({
      type: 'flat_rate',
      preferences: { amount: '10', currency: 'USD' },
    })
    expect(await unchanged(api, file(10))).toBe(true)

    const report = await deployConfig(parseConfig(file(12)).config, api)
    expect(reportHasFailures(report)).toBe(false)
    expect((api.all('/promotions')[0].actions as Payload[])[0]).toMatchObject({
      id: action.id,
      calculator: { preferences: { amount: '12' } },
    })
  })
})

describe('companies and catalogs', () => {
  it('writes a division after its parent, adds listed members and assigns a catalog', async () => {
    const api = new FakeApi()
    api.seed('/customers', [{ id: 'cust_1', email: 'buyer@example.com' }])
    api.seed('/products', [{ id: 'prod_1', slug: 'kettle', name: 'Kettle' }])
    api.seed('/companies', [])
    api.seed('/catalogs', [])
    const file = `
version: 1
companies:
  - name: Acme EMEA
    kind: division
    parent: Acme
    members: [buyer@example.com]
  - name: Acme
    kind: company
catalogs:
  - name: Trade assortment
    companies: [Acme]
    products: [kettle]
`
    const report = await deployConfig(parseConfig(file).config, api)
    expect(reportHasFailures(report)).toBe(false)
    const [root, division] = api.all('/companies')
    expect([root.name, division.name, division.parent_id]).toEqual(['Acme', 'Acme EMEA', root.id])
    expect((division.memberships as Payload[]).map((membership) => membership.email)).toEqual([
      'buyer@example.com',
    ])
    const [catalog] = api.all('/catalogs')
    expect(catalog.assignments).toMatchObject([
      { assignable_type: 'company', assignable_id: root.id },
    ])
    expect(api.members.get(`/catalogs/${catalog.id}`)).toEqual(['prod_1'])
    expect(await unchanged(api, file)).toBe(true)

    const captured = await introspect(api, { include: ['companies', 'catalogs'] })
    expect(captured.companies).toEqual([
      { name: 'Acme', kind: 'company' },
      { name: 'Acme EMEA', kind: 'division', parent: 'Acme', members: ['buyer@example.com'] },
    ])
    expect(captured.catalogs?.[0]).toMatchObject({ companies: ['Acme'], products: ['kettle'] })
  })

  it('keeps members a file does not list', async () => {
    const api = new FakeApi()
    api.seed('/customers', [{ id: 'cust_1', email: 'new@example.com' }])
    api.seed('/companies', [
      { name: 'Acme', kind: 'company', memberships: [{ id: 'mem_1', email: 'old@example.com' }] },
    ])
    const file = 'version: 1\ncompanies:\n  - name: Acme\n    members: [new@example.com]\n'
    await deployConfig(parseConfig(file).config, api)
    expect((api.all('/companies')[0].memberships as Payload[]).map((row) => row.email)).toEqual([
      'old@example.com',
      'new@example.com',
    ])
    expect(await unchanged(api, file)).toBe(true)
  })
})
