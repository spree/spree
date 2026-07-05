import { beforeAll, describe, expect, it } from 'vitest'
import type { Client } from '../src'
import { createTestClient } from './helpers'
import { fixtures } from './mocks/handlers'

describe('categories', () => {
  let client: Client
  beforeAll(() => {
    client = createTestClient()
  })

  describe('list', () => {
    it('returns paginated categories', async () => {
      const result = await client.categories.list()

      expect(result.data).toHaveLength(1)
      expect(result.data[0].name).toBe('Clothing')
      expect(result.meta.page).toBe(1)
    })
  })

  describe('get', () => {
    it('returns a category by ID', async () => {
      const result = await client.categories.get('ctg_1')
      expect(result.name).toBe(fixtures.category.name)
    })
  })
})
