import { HttpResponse, http } from 'msw'
import { describe, expect, it } from 'vitest'
import { API_PREFIX, createTestClient, paginated } from './helpers'
import { server } from './mocks/server'

const sampleOrder = {
  id: 'order_abc123',
  number: 'R123456789',
  state: 'complete',
  total: '99.99',
  created_at: '2026-05-01T00:00:00Z',
  updated_at: '2026-05-01T00:00:00Z',
}

const sampleLineItem = { id: 'li_1', quantity: 2, variant_id: 'variant_1' }
const samplePayment = { id: 'pay_1', state: 'checkout', amount: '99.99' }
const sampleRefund = { id: 'ref_1', amount: '10.0' }
const sampleFulfillment = { id: 'ful_1', status: 'shipped', tracking: 'INPOST-12345' }

describe('orders', () => {
  describe('list / get', () => {
    it('GETs /orders with Ransack filters', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/orders`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(paginated([sampleOrder]))
        }),
      )

      const res = await createTestClient().orders.list({ state_eq: 'complete' })

      expect(res.data[0]?.id).toBe('order_abc123')
      expect(url!.searchParams.get('q[state_eq]')).toBe('complete')
    })

    it('GETs /orders/:id', async () => {
      server.use(
        http.get(`${API_PREFIX}/orders/order_abc123`, () => HttpResponse.json(sampleOrder)),
      )

      const res = await createTestClient().orders.get('order_abc123')

      expect(res.number).toBe('R123456789')
    })
  })

  describe('lifecycle actions', () => {
    it.each([
      ['complete', 'complete'],
      ['cancel', 'cancel'],
      ['approve', 'approve'],
      ['resume', 'resume'],
    ] as const)('PATCHes /orders/:id/%s', async (method, segment) => {
      let hit = false
      server.use(
        http.patch(`${API_PREFIX}/orders/order_abc123/${segment}`, () => {
          hit = true
          return HttpResponse.json(sampleOrder)
        }),
      )

      // resume takes no params; the others accept an optional params arg.
      await (createTestClient().orders as Record<string, (...args: unknown[]) => Promise<unknown>>)[
        method
      ]('order_abc123')
      expect(hit).toBe(true)
    })

    it('POSTs /orders/:id/resend_confirmation', async () => {
      let hit = false
      server.use(
        http.post(`${API_PREFIX}/orders/order_abc123/resend_confirmation`, () => {
          hit = true
          return new HttpResponse(null, { status: 204 })
        }),
      )

      await createTestClient().orders.resendConfirmation('order_abc123')
      expect(hit).toBe(true)
    })
  })

  describe('nested line items', () => {
    it('POSTs a line item to the order', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(`${API_PREFIX}/orders/order_abc123/items`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json(sampleLineItem, { status: 201 })
        }),
      )

      await createTestClient().orders.items.create('order_abc123', {
        variant_id: 'variant_1',
        quantity: 2,
      })

      expect(body).toEqual({ variant_id: 'variant_1', quantity: 2 })
    })

    it('PATCHes a line item quantity', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.patch(`${API_PREFIX}/orders/order_abc123/items/li_1`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json({ ...sampleLineItem, quantity: 5 })
        }),
      )

      const res = await createTestClient().orders.items.update('order_abc123', 'li_1', {
        quantity: 5,
      })

      expect(body).toEqual({ quantity: 5 })
      expect(res.quantity).toBe(5)
    })

    it('DELETEs a line item', async () => {
      let hit = false
      server.use(
        http.delete(`${API_PREFIX}/orders/order_abc123/items/li_1`, () => {
          hit = true
          return new HttpResponse(null, { status: 204 })
        }),
      )

      await createTestClient().orders.items.delete('order_abc123', 'li_1')
      expect(hit).toBe(true)
    })
  })

  describe('nested payments', () => {
    it('POSTs a payment', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(`${API_PREFIX}/orders/order_abc123/payments`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json(samplePayment, { status: 201 })
        }),
      )

      await createTestClient().orders.payments.create('order_abc123', {
        payment_method_id: 'pm_1',
        amount: 99.99,
      })

      expect(body).toEqual({ payment_method_id: 'pm_1', amount: 99.99 })
    })

    it.each(['capture', 'void'] as const)('PATCHes /payments/:id/%s', async (action) => {
      let hit = false
      server.use(
        http.patch(`${API_PREFIX}/orders/order_abc123/payments/pay_1/${action}`, () => {
          hit = true
          return HttpResponse.json(samplePayment)
        }),
      )

      await createTestClient().orders.payments[action]('order_abc123', 'pay_1')
      expect(hit).toBe(true)
    })
  })

  describe('nested fulfillments', () => {
    it('POSTs a fulfillment', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(`${API_PREFIX}/orders/order_abc123/fulfillments`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json(sampleFulfillment, { status: 201 })
        }),
      )

      await createTestClient().orders.fulfillments.create('order_abc123', {
        stock_location_id: 'sloc_1',
        tracking: 'INPOST-12345',
        status: 'shipped',
        items: [{ item_id: 'li_1', quantity: 1 }],
      })

      expect(body).toEqual({
        stock_location_id: 'sloc_1',
        tracking: 'INPOST-12345',
        status: 'shipped',
        items: [{ item_id: 'li_1', quantity: 1 }],
      })
    })

    it('PATCHes a fulfillment update', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.patch(`${API_PREFIX}/orders/order_abc123/fulfillments/ful_1`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json(sampleFulfillment)
        }),
      )

      await createTestClient().orders.fulfillments.update('order_abc123', 'ful_1', {
        tracking: 'DPD-42',
        selected_delivery_rate_id: 'dr_1',
      })

      expect(body).toEqual({ tracking: 'DPD-42', selected_delivery_rate_id: 'dr_1' })
    })

    it.each([
      'fulfill',
      'cancel',
      'resume',
    ] as const)('PATCHes /fulfillments/:id/%s', async (action) => {
      let hit = false
      server.use(
        http.patch(`${API_PREFIX}/orders/order_abc123/fulfillments/ful_1/${action}`, () => {
          hit = true
          return HttpResponse.json(sampleFulfillment)
        }),
      )

      await createTestClient().orders.fulfillments[action]('order_abc123', 'ful_1')
      expect(hit).toBe(true)
    })
  })

  describe('nested refunds', () => {
    it('POSTs a refund', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(`${API_PREFIX}/orders/order_abc123/refunds`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json(sampleRefund, { status: 201 })
        }),
      )

      await createTestClient().orders.refunds.create('order_abc123', {
        payment_id: 'pay_1',
        amount: 10,
      })

      expect(body).toEqual({ payment_id: 'pay_1', amount: 10 })
    })
  })

  describe('nested gift cards & store credits', () => {
    it('applies a gift card via POST', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(`${API_PREFIX}/orders/order_abc123/gift_cards`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json({ id: 'gc_1', code: 'ABC' }, { status: 201 })
        }),
      )

      await createTestClient().orders.giftCards.apply('order_abc123', { code: 'ABC' })

      expect(body).toEqual({ code: 'ABC' })
    })

    it('applies store credit via POST', async () => {
      let hit = false
      server.use(
        http.post(`${API_PREFIX}/orders/order_abc123/store_credits`, () => {
          hit = true
          return HttpResponse.json(sampleOrder, { status: 201 })
        }),
      )

      await createTestClient().orders.storeCredits.apply('order_abc123')
      expect(hit).toBe(true)
    })

    it('removes store credit via DELETE', async () => {
      let hit = false
      server.use(
        http.delete(`${API_PREFIX}/orders/order_abc123/store_credits`, () => {
          hit = true
          return new HttpResponse(null, { status: 204 })
        }),
      )

      await createTestClient().orders.storeCredits.remove('order_abc123')
      expect(hit).toBe(true)
    })
  })
})
