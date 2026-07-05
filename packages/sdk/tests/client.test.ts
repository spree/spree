import { describe, expect, it } from 'vitest'
import { createClient } from '../src'
import { TEST_API_KEY, TEST_BASE_URL } from './helpers'

describe('createClient', () => {
  it('creates a client via factory function', () => {
    const client = createClient({
      baseUrl: TEST_BASE_URL,
      publishableKey: TEST_API_KEY,
    })
    expect(client).toBeDefined()
    expect(client.products).toBeDefined()
  })

  it('strips trailing slash from baseUrl', async () => {
    const client = createClient({
      baseUrl: `${TEST_BASE_URL}/`,
      publishableKey: TEST_API_KEY,
    })
    const result = await client.products.list()
    expect(result.data).toBeDefined()
  })

  it('accepts a custom fetch implementation', async () => {
    let capturedUrl = ''
    const customFetch = async (input: string | URL | Request, _init?: RequestInit) => {
      capturedUrl = input.toString()
      return new Response(
        JSON.stringify({
          data: [],
          meta: {
            page: 1,
            limit: 25,
            count: 0,
            pages: 0,
            from: 0,
            to: 0,
            in: 0,
            previous: null,
            next: null,
          },
        }),
        {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        },
      )
    }

    const client = createClient({
      baseUrl: TEST_BASE_URL,
      publishableKey: TEST_API_KEY,
      fetch: customFetch,
    })

    await client.products.list()
    expect(capturedUrl).toContain('/api/v3/store/products')
  })

  it('sends x-spree-api-key header on every request', async () => {
    let capturedHeaders: Record<string, string> = {}
    const customFetch = async (_input: string | URL | Request, init?: RequestInit) => {
      capturedHeaders = Object.fromEntries(
        Object.entries((init?.headers as Record<string, string>) || {}),
      )
      return new Response(
        JSON.stringify({
          data: [],
          meta: {
            page: 1,
            limit: 25,
            count: 0,
            pages: 0,
            from: 0,
            to: 0,
            in: 0,
            previous: null,
            next: null,
          },
        }),
        {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        },
      )
    }

    const client = createClient({
      baseUrl: TEST_BASE_URL,
      publishableKey: 'my-secret-key',
      fetch: customFetch,
    })

    await client.products.list()
    expect(capturedHeaders['x-spree-api-key']).toBe('my-secret-key')
  })

  it('sends Authorization header when token is provided', async () => {
    let capturedHeaders: Record<string, string> = {}
    const customFetch = async (_input: string | URL | Request, init?: RequestInit) => {
      capturedHeaders = Object.fromEntries(
        Object.entries((init?.headers as Record<string, string>) || {}),
      )
      return new Response(
        JSON.stringify({
          data: [],
          meta: {
            page: 1,
            limit: 25,
            count: 0,
            pages: 0,
            from: 0,
            to: 0,
            in: 0,
            previous: null,
            next: null,
          },
        }),
        {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        },
      )
    }

    const client = createClient({
      baseUrl: TEST_BASE_URL,
      publishableKey: TEST_API_KEY,
      fetch: customFetch,
    })

    await client.products.list({}, { token: 'my-jwt-token' })
    expect(capturedHeaders.Authorization).toBe('Bearer my-jwt-token')
  })

  it('sends locale and currency headers when provided', async () => {
    let capturedHeaders: Record<string, string> = {}
    const customFetch = async (_input: string | URL | Request, init?: RequestInit) => {
      capturedHeaders = Object.fromEntries(
        Object.entries((init?.headers as Record<string, string>) || {}),
      )
      return new Response(
        JSON.stringify({
          data: [],
          meta: {
            page: 1,
            limit: 25,
            count: 0,
            pages: 0,
            from: 0,
            to: 0,
            in: 0,
            previous: null,
            next: null,
          },
        }),
        {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        },
      )
    }

    const client = createClient({
      baseUrl: TEST_BASE_URL,
      publishableKey: TEST_API_KEY,
      fetch: customFetch,
    })

    await client.products.list({}, { locale: 'fr', currency: 'EUR', channel: 'pos' })
    expect(capturedHeaders['x-spree-locale']).toBe('fr')
    expect(capturedHeaders['x-spree-currency']).toBe('EUR')
    expect(capturedHeaders['x-spree-channel']).toBe('pos')
  })

  it('uses client-level channel default when no per-request override', async () => {
    let capturedHeaders: Record<string, string> = {}
    const customFetch = async (_input: string | URL | Request, init?: RequestInit) => {
      capturedHeaders = Object.fromEntries(
        Object.entries((init?.headers as Record<string, string>) || {}),
      )
      return new Response(
        JSON.stringify({
          data: [],
          meta: {
            page: 1,
            limit: 25,
            count: 0,
            pages: 0,
            from: 0,
            to: 0,
            in: 0,
            previous: null,
            next: null,
          },
        }),
        {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        },
      )
    }

    const client = createClient({
      baseUrl: TEST_BASE_URL,
      publishableKey: TEST_API_KEY,
      channel: 'wholesale',
      fetch: customFetch,
    })

    await client.products.list()
    expect(capturedHeaders['x-spree-channel']).toBe('wholesale')

    // Per-request override wins over the client default
    await client.products.list({}, { channel: 'pos' })
    expect(capturedHeaders['x-spree-channel']).toBe('pos')
  })

  it('exposes all resource namespaces directly', () => {
    const client = createClient({
      baseUrl: TEST_BASE_URL,
      publishableKey: TEST_API_KEY,
    })

    expect(client.auth).toBeDefined()
    expect(client.products).toBeDefined()
    expect(client.categories).toBeDefined()
    expect(client.countries).toBeDefined()
    expect(client.currencies).toBeDefined()
    expect(client.locales).toBeDefined()
    expect(client.carts).toBeDefined()
    expect(client.orders).toBeDefined()
    expect(client.customer).toBeDefined()
    expect(client.wishlists).toBeDefined()
  })

  it('supports setLocale, setCurrency, setCountry, setChannel', () => {
    const client = createClient({
      baseUrl: TEST_BASE_URL,
      publishableKey: TEST_API_KEY,
    })

    expect(() => {
      client.setLocale('fr')
      client.setCurrency('EUR')
      client.setCountry('FR')
      client.setChannel('pos')
    }).not.toThrow()
  })

  it('setChannel updates the channel applied to subsequent requests', async () => {
    let capturedHeaders: Record<string, string> = {}
    const customFetch = async (_input: string | URL | Request, init?: RequestInit) => {
      capturedHeaders = Object.fromEntries(
        Object.entries((init?.headers as Record<string, string>) || {}),
      )
      return new Response(
        JSON.stringify({
          data: [],
          meta: {
            page: 1,
            limit: 25,
            count: 0,
            pages: 0,
            from: 0,
            to: 0,
            in: 0,
            previous: null,
            next: null,
          },
        }),
        {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        },
      )
    }

    const client = createClient({
      baseUrl: TEST_BASE_URL,
      publishableKey: TEST_API_KEY,
      fetch: customFetch,
    })

    await client.products.list()
    expect(capturedHeaders['x-spree-channel']).toBeUndefined()

    client.setChannel('pos')
    await client.products.list()
    expect(capturedHeaders['x-spree-channel']).toBe('pos')

    client.setChannel('wholesale')
    await client.products.list()
    expect(capturedHeaders['x-spree-channel']).toBe('wholesale')
  })
})
