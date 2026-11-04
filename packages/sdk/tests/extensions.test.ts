import { describe, expect, expectTypeOf, it } from 'vitest'
import { createClient, defineStoreExtension } from '../src'
import { TEST_API_KEY, TEST_BASE_URL } from './helpers'

interface Quote {
  id: string
}

const quotes = defineStoreExtension('quotes', ({ request }) => ({
  get: (id: string) => request<Quote>('GET', `/quotes/${id}`),
}))

function recordingClient() {
  const calls: { url: string; headers: Headers }[] = []
  const fetch = async (input: string | URL | Request, init?: RequestInit) => {
    calls.push({ url: input.toString(), headers: new Headers(init?.headers) })
    return new Response(JSON.stringify({ id: 'quote_1' }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    })
  }
  const client = createClient({
    baseUrl: TEST_BASE_URL,
    publishableKey: TEST_API_KEY,
    fetch,
    retry: false,
  })
  return { client, calls }
}

describe('client.extend', () => {
  it("adds the extension's namespace, calling the Store API with the client's key", async () => {
    const { client, calls } = recordingClient()
    const extended = client.extend(quotes)

    const quote = await extended.quotes.get('quote_1')

    expect(quote).toEqual({ id: 'quote_1' })
    expect(calls[0].url).toBe(`${TEST_BASE_URL}/api/v3/store/quotes/quote_1`)
    expect(calls[0].headers.get('x-spree-api-key')).toBe(TEST_API_KEY)
    expectTypeOf(extended.quotes.get).returns.resolves.toEqualTypeOf<Quote>()
  })

  it('keeps the built-in resources and leaves the original client as it was', () => {
    const { client } = recordingClient()
    const extended = client.extend(quotes)

    expect(extended.products).toBe(client.products)
    expect('quotes' in client).toBe(false)
  })

  it('follows defaults set on the original client after extending', async () => {
    const { client, calls } = recordingClient()
    const extended = client.extend(quotes)

    client.setLocale('fr')
    await extended.quotes.get('quote_1')

    expect(calls[0].headers.get('x-spree-locale')).toBe('fr')
  })

  it('chains extensions', () => {
    const { client } = recordingClient()
    const wishlists = defineStoreExtension('savedLists', () => ({ count: () => 0 }))

    const extended = client.extend(quotes).extend(wishlists)

    expect(extended.quotes).toBeDefined()
    expect(extended.savedLists.count()).toBe(0)
  })

  it('refuses a name the client already has', () => {
    const { client } = recordingClient()
    const products = defineStoreExtension('products', () => ({}))

    expect(() => client.extend(products)).toThrow(TypeError)
    expect(() => client.extend(quotes).extend(quotes)).toThrow(/already has "quotes"/)
  })

  it('refuses an extension of another API', () => {
    const { client } = recordingClient()
    const adminOnly = Object.freeze({
      api: 'admin' as const,
      name: 'quotes' as const,
      build: () => ({}),
    })

    // @ts-expect-error an admin extension does not fit the Store client
    expect(() => client.extend(adminOnly)).toThrow(/admin API, not the store API/)
  })

  it('refuses anything that is not an extension', () => {
    const { client } = recordingClient()

    // @ts-expect-error not an extension
    expect(() => client.extend({ name: 'quotes' })).toThrow(TypeError)
  })
})
