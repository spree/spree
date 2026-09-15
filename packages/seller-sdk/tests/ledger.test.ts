import { HttpResponse, http } from 'msw'
import { describe, expect, it } from 'vitest'
import { createSellerClient } from '../src'
import { server } from './mocks/server'

const API = 'http://api.test/api/v3/seller'

function client() {
  return createSellerClient({ baseUrl: 'http://api.test', token: 'jwt' })
}

describe('the seller ledger', () => {
  it('reads the balances as a plain list, with no paging params', async () => {
    let search = ''
    server.use(
      http.get(`${API}/balances`, ({ request }) => {
        search = new URL(request.url).search
        return HttpResponse.json({ data: [{ currency: 'USD', balance: '25.0' }] })
      }),
    )

    const res = await client().balances.list()

    expect(res.data[0]?.currency).toBe('USD')
    expect(search).toBe('')
  })

  // The panel filters a seller's earnings to one order and to one settlement;
  // both go through Ransack, so they must arrive as `q[...]` rather than as
  // bare params the controller would ignore.
  it('sends a transfer filter as a Ransack predicate', async () => {
    let search = ''
    server.use(
      http.get(`${API}/transfers`, ({ request }) => {
        search = decodeURIComponent(new URL(request.url).search)
        return HttpResponse.json({ data: [], meta: { page: 1, limit: 25, count: 0, pages: 0 } })
      }),
    )

    await client().transfers.list({ order_id_eq: 'or_1', limit: 10 })

    expect(search).toContain('q[order_id_eq]=or_1')
    expect(search).toContain('limit=10')
  })

  it('reads one payout', async () => {
    server.use(
      http.get(`${API}/payouts/vpo_1`, () =>
        HttpResponse.json({ id: 'vpo_1', status: 'completed' }),
      ),
    )

    expect((await client().payouts.get('vpo_1')).status).toBe('completed')
  })

  // The order page asks for the shares of the basket's payment; without the
  // expand the server sends none and the card renders empty.
  it("asks for an order's payment shares as one comma-separated expand", async () => {
    let search = ''
    server.use(
      http.get(`${API}/orders/or_1`, ({ request }) => {
        search = decodeURIComponent(new URL(request.url).search)
        return HttpResponse.json({ id: 'or_1' })
      }),
    )

    await client().orders.get('or_1', { expand: ['payment_splits'] })

    expect(search).toBe('?expand=payment_splits')
  })

  it('asks for nothing extra when no expand is given', async () => {
    let search = 'unset'
    server.use(
      http.get(`${API}/orders/or_1`, ({ request }) => {
        search = new URL(request.url).search
        return HttpResponse.json({ id: 'or_1' })
      }),
    )

    await client().orders.get('or_1')

    expect(search).toBe('')
  })
})
