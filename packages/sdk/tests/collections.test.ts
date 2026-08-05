import { beforeAll, describe, expect, it } from 'vitest'
import type { Client } from '../src'
import { createTestClient } from './helpers'
import { fixtures } from './mocks/handlers'

describe('collections', () => {
  let client: Client
  beforeAll(() => {
    client = createTestClient()
  })

  describe('list', () => {
    it('returns paginated collections', async () => {
      const result = await client.collections.list()

      expect(result.data).toHaveLength(1)
      expect(result.data[0].name).toBe(fixtures.collection.name)
      expect(result.meta.page).toBe(1)
    })
  })

  describe('get', () => {
    it('returns a collection by ID', async () => {
      const result = await client.collections.get('coll_1')
      expect(result.name).toBe(fixtures.collection.name)
    })

    it('returns a collection by permalink', async () => {
      const result = await client.collections.get('summer-sale')
      expect(result.permalink).toBe(fixtures.collection.permalink)
    })
  })

  describe('products.list', () => {
    it("returns the collection's products", async () => {
      const result = await client.collections.products.list('coll_1')

      expect(result.data).toHaveLength(1)
      expect(result.data[0].name).toBe(fixtures.product.name)
      expect(result.meta.page).toBe(1)
    })

    it('forwards filters and sort to the listing', async () => {
      const result = await client.collections.products.list('summer-sale', {
        sort: '-price',
        in_stock: true,
        limit: 10,
      })

      expect(result.data).toHaveLength(1)
    })
  })
})
