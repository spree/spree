import { HttpResponse, http } from 'msw'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { createSellerClient } from '../src'
import { server } from './mocks/server'

/**
 * The post-sale endpoints gate their line items behind `expand`, so what the
 * client puts in the query string is the difference between a card that
 * renders its contents and one that renders an empty shell.
 *
 * These assert the raw query string rather than the parsed params, because the
 * bug they exist for was a *shape* bug: an array became repeated `expand=`
 * params, and Rack collapses those to the last value — so the server saw only
 * `reason` and every line item silently vanished. A test reading the client's
 * own options object would have passed.
 */
const requested: string[] = []

function record(path: string) {
  return http.get(`http://api.test/api/v3/seller/orders/:orderId/${path}`, ({ request }) => {
    requested.push(new URL(request.url).search)
    return HttpResponse.json({ data: [] })
  })
}

beforeEach(() => {
  server.use(record('returns'), record('exchanges'), record('claims'))
})
afterEach(() => {
  requested.length = 0
})

function client() {
  return createSellerClient({ baseUrl: 'http://api.test', token: 'jwt' })
}

describe('post-sale expand parameters', () => {
  it('asks for a return’s line items as one comma-separated value', async () => {
    await client().orders.returns.list('or_1')

    const search = requested[0]
    expect(search).toContain('expand=')
    // One expand key, not several — repeated params collapse server-side.
    expect(search.match(/expand=/g)).toHaveLength(1)
    expect(decodeURIComponent(search)).toContain('return_line_items')
    expect(decodeURIComponent(search)).toContain('return_line_items.variant')
  })

  it('asks for an exchange’s line items and both variants', async () => {
    await client().orders.exchanges.list('or_1')

    const search = decodeURIComponent(requested[0])
    expect(search.match(/expand=/g)).toHaveLength(1)
    expect(search).toContain('exchange_line_items.original_variant')
    expect(search).toContain('exchange_line_items.new_variant')
  })

  it('asks for a claim’s line items', async () => {
    await client().orders.claims.list('or_1')

    const search = decodeURIComponent(requested[0])
    expect(search.match(/expand=/g)).toHaveLength(1)
    expect(search).toContain('claim_line_items')
  })
})
