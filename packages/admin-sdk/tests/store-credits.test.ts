import { HttpResponse, http } from 'msw'
import { describe, expect, it } from 'vitest'
import { API_PREFIX, createTestClient, paginated } from './helpers'
import { server } from './mocks/server'

const sampleStoreCredit = {
  id: 'credit_abc123',
  amount: '50.0',
  amount_used: '10.0',
  amount_authorized: '0.0',
  amount_remaining: '40.0',
  display_amount: '$50.00',
  display_amount_used: '$10.00',
  display_amount_authorized: '$0.00',
  display_amount_remaining: '$40.00',
  currency: 'USD',
  memo: 'Goodwill for a late delivery',
  metadata: {},
  originator_type: null,
  originator_id: null,
  customer_id: 'cus_abc123',
  created_by_id: 'adm_abc123',
  created_at: '2026-05-01T00:00:00Z',
  updated_at: '2026-05-01T00:00:00Z',
}

const sampleEvent = {
  id: 'scevt_abc123',
  action: 'allocation',
  display_action: 'Allocated',
  amount: '50.0',
  display_amount: '$50.00',
  authorization_code: '1-SC-20260501000000000000',
  store_credit_id: 'credit_abc123',
  originator_type: null,
  originator_id: null,
  created_at: '2026-05-01T00:00:00Z',
  updated_at: '2026-05-01T00:00:00Z',
}

describe('storeCredits', () => {
  describe('list', () => {
    it('GETs /store_credits and returns paginated data', async () => {
      server.use(
        http.get(`${API_PREFIX}/store_credits`, () =>
          HttpResponse.json(paginated([sampleStoreCredit])),
        ),
      )

      const res = await createTestClient().storeCredits.list()

      expect(res.data).toHaveLength(1)
      expect(res.data[0]?.id).toBe('credit_abc123')
    })

    it('surfaces the per-currency outstanding totals from meta', async () => {
      server.use(
        http.get(`${API_PREFIX}/store_credits`, () =>
          HttpResponse.json({
            data: [sampleStoreCredit],
            meta: {
              page: 1,
              limit: 25,
              count: 1,
              pages: 1,
              totals: [
                {
                  currency: 'USD',
                  amount: '50.0',
                  amount_used: '10.0',
                  amount_authorized: '0.0',
                  amount_remaining: '40.0',
                  display_amount: '$50.00',
                  display_amount_used: '$10.00',
                  display_amount_authorized: '$0.00',
                  display_amount_remaining: '$40.00',
                },
              ],
            },
          }),
        ),
      )

      const res = await createTestClient().storeCredits.list()

      expect(res.meta.totals).toHaveLength(1)
      expect(res.meta.totals[0]?.currency).toBe('USD')
      expect(res.meta.totals[0]?.display_amount_remaining).toBe('$40.00')
    })

    it('wraps Ransack predicates via transformListParams', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/store_credits`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(paginated([]))
        }),
      )

      await createTestClient().storeCredits.list({
        outstanding: true,
        customer_email_cont: 'holder@',
      })

      expect(url!.searchParams.get('q[outstanding]')).toBe('true')
      expect(url!.searchParams.get('q[customer_email_cont]')).toBe('holder@')
    })
  })

  describe('get', () => {
    it('GETs /store_credits/:id and forwards expand params', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/store_credits/credit_abc123`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(sampleStoreCredit)
        }),
      )

      const res = await createTestClient().storeCredits.get('credit_abc123', {
        expand: ['customer'],
      })

      expect(res.id).toBe('credit_abc123')
      expect(url!.searchParams.get('expand')).toBe('customer')
    })
  })

  describe('events', () => {
    it("GETs the credit's ledger", async () => {
      server.use(
        http.get(`${API_PREFIX}/store_credits/credit_abc123/events`, () =>
          HttpResponse.json(paginated([sampleEvent])),
        ),
      )

      const res = await createTestClient().storeCredits.events.list('credit_abc123')

      expect(res.data).toHaveLength(1)
      expect(res.data[0]?.action).toBe('allocation')
    })
  })
})
