import { describe, expect, it } from 'vitest'
import { createAdminClient, defineAdminExtension, SpreeError } from '../src'
import { BASE_URL } from './helpers'

const quotes = defineAdminExtension('quotes', ({ request }) => ({
  send: (id: string) => request<{ id: string }>('PATCH', `/quotes/${id}/send`, { body: {} }),
}))

function recordingClient(statuses: number[] = []) {
  const calls: { url: string; method?: string; headers: Headers }[] = []
  const fetch = async (input: string | URL | Request, init?: RequestInit) => {
    calls.push({ url: input.toString(), method: init?.method, headers: new Headers(init?.headers) })
    const status = statuses.shift() ?? 200
    const body =
      status === 200
        ? { id: 'quote_1' }
        : { error: { code: 'unauthorized', message: 'Unauthorized' } }
    return new Response(JSON.stringify(body), {
      status,
      headers: { 'Content-Type': 'application/json' },
    })
  }
  const client = createAdminClient({
    baseUrl: BASE_URL,
    jwtToken: 'old',
    storeId: 'store_1',
    fetch,
    retry: false,
  })
  return { client, calls }
}

describe('client.extend', () => {
  it('calls the Admin API with the store and the token set after extending', async () => {
    const { client, calls } = recordingClient()
    const extended = client.extend(quotes)

    client.setToken('new')
    await extended.quotes.send('quote_1')

    expect(calls[0].url).toBe(`${BASE_URL}/api/v3/admin/quotes/quote_1/send`)
    expect(calls[0].method).toBe('PATCH')
    expect(calls[0].headers.get('Authorization')).toBe('Bearer new')
    expect(calls[0].headers.get('X-Spree-Store-Id')).toBe('store_1')
  })

  it("retries through the client's unauthorized handler", async () => {
    const { client, calls } = recordingClient([401, 200])
    const extended = client.extend(quotes)
    client.onUnauthorized(async () => {
      client.setToken('refreshed')
      return true
    })

    await extended.quotes.send('quote_1')

    expect(calls).toHaveLength(2)
    expect(calls[1].headers.get('Authorization')).toBe('Bearer refreshed')
  })

  it('surfaces API errors as SpreeError', async () => {
    const { client } = recordingClient([401])

    await expect(client.extend(quotes).quotes.send('quote_1')).rejects.toBeInstanceOf(SpreeError)
  })

  it('refuses a name the client already has', () => {
    const { client } = recordingClient()

    expect(() => client.extend(defineAdminExtension('orders', () => ({})))).toThrow(TypeError)
    expect(() => client.extend(defineAdminExtension('setToken', () => ({})))).toThrow(TypeError)
  })
})
