import { describe, expect, it } from 'vitest'
import { client } from './helpers'
import { getCredentials } from './setup'

describe('products', () => {
  it('lists products with correct shape', async () => {
    const result = await client().products.list()

    expect(result.data).toBeInstanceOf(Array)
    expect(result.data.length).toBeGreaterThan(0)
    expect(result.meta).toHaveProperty('count')

    const product = result.data[0]
    expect(product.id).toMatch(/^prod_/)
    expect(product).toHaveProperty('name')
    expect(product).toHaveProperty('slug')
    expect(product).toHaveProperty('price')
    expect(product).toHaveProperty('purchasable')
    expect(product).toHaveProperty('in_stock')
  })

  it('gets a product by slug', async () => {
    const creds = getCredentials()
    const product = await client().products.get(creds.product_slug)

    expect(product.id).toBe(creds.product_id)
    expect(product.slug).toBe(creds.product_slug)
  })

  it('returns product filters', async () => {
    const result = await client().products.filters()

    expect(result).toHaveProperty('filters')
    expect(result).toHaveProperty('sort_options')
  })
})

describe('categories', () => {
  it('lists categories', async () => {
    const result = await client().categories.list()

    expect(result.data).toBeInstanceOf(Array)
    expect(result.data.length).toBeGreaterThan(0)

    const category = result.data[0]
    expect(category.id).toMatch(/^ctg_/)
    expect(category).toHaveProperty('name')
    expect(category).toHaveProperty('permalink')
  })
})
