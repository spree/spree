import { describe, expect, it } from 'vitest'
import { createClient } from '../src'
import { createTestClient, TEST_API_KEY, TEST_BASE_URL } from './helpers'

describe('store', () => {
  it('gets the current store with its SEO metadata', async () => {
    const client = createTestClient()

    const store = await client.store.get()

    expect(store.name).toBe('Coffee Shop')
    expect(store.seo_title).toBe('Coffee Shop')
    expect(store.meta_description).toBe('Freshly roasted coffee')
  })

  it('requests the configured locale', async () => {
    const client = createClient({
      baseUrl: TEST_BASE_URL,
      publishableKey: TEST_API_KEY,
      locale: 'de',
    })

    const store = await client.store.get()

    expect(store.seo_title).toBe('Kaffeeladen')
  })
})
