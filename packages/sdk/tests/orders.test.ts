import { HttpResponse, http } from 'msw'
import { beforeAll, describe, expect, it } from 'vitest'
import type { Client } from '../src'
import { createTestClient, TEST_BASE_URL } from './helpers'
import { fixtures } from './mocks/handlers'
import { server } from './mocks/server'

const API_PREFIX = `${TEST_BASE_URL}/api/v3/store`

describe('orders', () => {
  let client: Client
  beforeAll(() => {
    client = createTestClient()
  })
  const opts = { token: 'user-jwt' }

  describe('get', () => {
    it('returns an order by prefixed ID', async () => {
      const result = await client.orders.get('or_abc123', undefined, opts)
      expect(result.id).toBe('or_1')
      expect(result.completed_at).toBeDefined()
    })

    it('works with order token for guest access', async () => {
      const result = await client.orders.get('or_abc123', undefined, {
        spreeToken: 'guest-token',
      })
      expect(result).toBeDefined()
    })
  })

  describe('paying for a draft order', () => {
    const session = {
      id: 'ps_1',
      status: 'pending',
      amount: '99.99',
      currency: 'USD',
      payment_method_id: 'pm_1',
      order_id: 'or_draft',
      cart_id: null,
    }
    it('places the draft', async () => {
      server.use(
        http.post(`${API_PREFIX}/orders/or_draft/complete`, () =>
          HttpResponse.json(fixtures.order),
        ),
      )

      const result = await client.orders.complete('or_draft', opts)
      expect(result.id).toBe('or_1')
    })

    it('creates, reads, updates and completes its payment sessions', async () => {
      server.use(
        http.post(`${API_PREFIX}/orders/or_draft/payment_sessions`, () =>
          HttpResponse.json(session, { status: 201 }),
        ),
        http.get(`${API_PREFIX}/orders/or_draft/payment_sessions/ps_1`, () =>
          HttpResponse.json(session),
        ),
        http.patch(`${API_PREFIX}/orders/or_draft/payment_sessions/ps_1`, () =>
          HttpResponse.json(session),
        ),
        http.patch(`${API_PREFIX}/orders/or_draft/payment_sessions/ps_1/complete`, () =>
          HttpResponse.json({ ...session, status: 'completed' }),
        ),
      )

      const created = await client.orders.paymentSessions.create(
        'or_draft',
        { payment_method_id: 'pm_1' },
        opts,
      )
      expect(created.order_id).toBe('or_draft')
      expect((await client.orders.paymentSessions.get('or_draft', 'ps_1', opts)).id).toBe('ps_1')
      expect(
        (await client.orders.paymentSessions.update('or_draft', 'ps_1', { amount: '50.00' }, opts))
          .id,
      ).toBe('ps_1')
      const completed = await client.orders.paymentSessions.complete(
        'or_draft',
        'ps_1',
        { session_result: 'success' },
        opts,
      )
      expect(completed.status).toBe('completed')
    })
  })

  describe('customer.orders', () => {
    it('lists customer orders', async () => {
      const result = await client.customer.orders.list(undefined, opts)
      expect(result.data).toHaveLength(1)
      expect(result.meta.page).toBe(1)
    })

    it('gets a customer order by ID', async () => {
      const result = await client.customer.orders.get('or_abc123', undefined, opts)
      expect(result.id).toBe('or_1')
    })
  })
})
