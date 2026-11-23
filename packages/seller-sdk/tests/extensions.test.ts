import { describe, expect, it } from 'vitest'
import { createSellerClient, defineSellerExtension } from '../src'

const BASE_URL = 'https://demo.spreecommerce.org'

const payouts = defineSellerExtension('payoutReports', ({ request }) => ({
  list: () => request<{ data: unknown[] }>('GET', '/payout_reports'),
}))

describe('client.extend', () => {
  it('calls the Seller API as the seller the client acts for', async () => {
    const calls: { url: string; headers: Headers }[] = []
    const fetch = async (input: string | URL | Request, init?: RequestInit) => {
      calls.push({ url: input.toString(), headers: new Headers(init?.headers) })
      return new Response(JSON.stringify({ data: [] }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      })
    }
    const client = createSellerClient({ baseUrl: BASE_URL, jwtToken: 'jwt', fetch, retry: false })
    const extended = client.extend(payouts)

    client.setSeller('seller_1')
    await extended.payoutReports.list()

    expect(calls[0].url).toBe(`${BASE_URL}/api/v3/seller/payout_reports`)
    expect(calls[0].headers.get('X-Spree-Seller-Id')).toBe('seller_1')
    expect(calls[0].headers.get('Authorization')).toBe('Bearer jwt')
  })
})
