import { beforeAll, describe, expect, it } from 'vitest'
import type { Client } from '../src'
import { createTestClient } from './helpers'

describe('custom fields', () => {
  let client: Client
  beforeAll(() => {
    client = createTestClient()
  })

  describe('first-class parent: products', () => {
    it('lists', async () => {
      const result = await client.products.customFields.list('prod_1')
      expect(result.data).toHaveLength(1)
      expect(result.data[0].id).toBe('cf_1')
      expect(result.data[0].custom_field_definition_id).toBe('cfdef_1')
      const echoed = (result.data[0] as { _route?: { parent: string; parent_id: string } })._route
      expect(echoed).toEqual({ parent: 'products', parent_id: 'prod_1' })
    })

    it('gets a single custom field', async () => {
      const cf = await client.products.customFields.get('prod_1', 'cf_1')
      expect(cf.value).toBe('wool')
    })

    it('creates a custom field', async () => {
      const cf = await client.products.customFields.create('prod_1', {
        custom_field_definition_id: 'cfdef_1',
        value: 'wool',
      })
      expect(cf.id).toBe('cf_1')
    })

    it('updates a custom field', async () => {
      const cf = await client.products.customFields.update('prod_1', 'cf_1', { value: 'cotton' })
      expect(cf.value).toBe('cotton')
    })

    it('deletes a custom field', async () => {
      await expect(client.products.customFields.delete('prod_1', 'cf_1')).resolves.toBeUndefined()
    })
  })

  describe.each([
    ['orders', 'or_1', 'orders'],
    ['customers', 'cus_1', 'customers'],
    ['variants', 'variant_1', 'variants'],
    ['categories', 'ctg_1', 'categories'],
    ['optionTypes', 'opt_1', 'option_types'],
  ] as const)('first-class parent: %s', (resource, parentId, routeSegment) => {
    it('lists via the dedicated accessor and hits the matching route', async () => {
      const accessor = client[resource].customFields
      const result = await accessor.list(parentId)
      expect(result.data[0].id).toBe('cf_1')
      // The mock echoes the matched route + parentId so we catch wiring bugs:
      // a wrong nesting (e.g. `client.orders.customFields` hitting /products/...)
      // would surface as a parent-segment mismatch here.
      const echoed = (result.data[0] as { _route?: { parent: string; parent_id: string } })._route
      expect(echoed).toEqual({ parent: routeSegment, parent_id: parentId })
    })
  })

  describe('top-level customFieldDefinitions', () => {
    it('lists definitions', async () => {
      const result = await client.customFieldDefinitions.list()
      expect(result.data).toHaveLength(1)
      expect(result.data[0].field_type).toBe('short_text')
    })

    it('gets a definition', async () => {
      const defn = await client.customFieldDefinitions.get('cfdef_1')
      expect(defn.key).toBe('fabric')
    })

    it('creates a definition', async () => {
      const defn = await client.customFieldDefinitions.create({
        namespace: 'specs',
        key: 'fabric',
        label: 'Fabric',
        field_type: 'short_text',
        resource_type: 'Spree::Product',
        storefront_visible: true,
      })
      expect(defn.id).toBe('cfdef_1')
    })

    it('updates a definition', async () => {
      const defn = await client.customFieldDefinitions.update('cfdef_1', {
        label: 'Updated label',
      })
      expect(defn.label).toBe('Updated label')
    })

    it('deletes a definition', async () => {
      await expect(client.customFieldDefinitions.delete('cfdef_1')).resolves.toBeUndefined()
    })
  })

  describe('generic escape hatch — customFields(ownerType, ownerId)', () => {
    it('routes Spree::Product to /products', async () => {
      const accessor = client.customFields('Spree::Product', 'prod_1')
      const result = await accessor.list()
      expect(result.data[0].id).toBe('cf_1')
      const echoed = (result.data[0] as { _route?: { parent: string; parent_id: string } })._route
      expect(echoed).toEqual({ parent: 'products', parent_id: 'prod_1' })
    })

    it('routes Spree::User to /customers (not /users)', async () => {
      const accessor = client.customFields('Spree::User', 'cus_1')
      const result = await accessor.list()
      expect(result.data[0].id).toBe('cf_1')
      const echoed = (result.data[0] as { _route?: { parent: string; parent_id: string } })._route
      expect(echoed).toEqual({ parent: 'customers', parent_id: 'cus_1' })
    })

    it('supports CRUD via the curried accessor', async () => {
      const accessor = client.customFields('Spree::Order', 'or_1')

      const cf = await accessor.create({ custom_field_definition_id: 'cfdef_1', value: 'wool' })
      expect(cf.id).toBe('cf_1')

      const updated = await accessor.update('cf_1', { value: 'cotton' })
      expect(updated.value).toBe('cotton')

      await expect(accessor.delete('cf_1')).resolves.toBeUndefined()
    })

    it('throws on unknown owner type', () => {
      expect(() => client.customFields('Spree::Sasquatch' as never, 'sas_1')).toThrow(
        /Unknown custom-field owner type/,
      )
    })
  })
})
