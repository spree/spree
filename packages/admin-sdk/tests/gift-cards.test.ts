import { HttpResponse, http } from 'msw'
import { describe, expect, it } from 'vitest'
import { API_PREFIX, createTestClient, paginated } from './helpers'
import { server } from './mocks/server'

const sampleGiftCard = {
  id: 'gc_abc123',
  code: 'ABCD-EFGH-IJKL',
  amount: '100.0',
  amount_used: '0.0',
  amount_remaining: '100.0',
  currency: 'USD',
  state: 'active',
  expires_at: null,
  created_at: '2026-05-01T00:00:00Z',
  updated_at: '2026-05-01T00:00:00Z',
}

const sampleGiftCardBatch = {
  id: 'gcb_abc123',
  prefix: 'XMAS',
  codes_count: 50,
  amount: '25.0',
  currency: 'USD',
  created_at: '2026-05-01T00:00:00Z',
  updated_at: '2026-05-01T00:00:00Z',
}

describe('giftCards', () => {
  describe('list', () => {
    it('GETs /gift_cards and returns paginated data', async () => {
      server.use(
        http.get(`${API_PREFIX}/gift_cards`, () => HttpResponse.json(paginated([sampleGiftCard]))),
      )

      const res = await createTestClient().giftCards.list()

      expect(res.data).toHaveLength(1)
      expect(res.data[0]?.id).toBe('gc_abc123')
    })

    it('wraps Ransack predicates via transformListParams', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/gift_cards`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(paginated([]))
        }),
      )

      await createTestClient().giftCards.list({ state_eq: 'active', code_cont: 'ABCD' })

      expect(url!.searchParams.get('q[state_eq]')).toBe('active')
      expect(url!.searchParams.get('q[code_cont]')).toBe('ABCD')
    })
  })

  describe('get', () => {
    it('GETs /gift_cards/:id and forwards expand params', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/gift_cards/gc_abc123`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(sampleGiftCard)
        }),
      )

      const res = await createTestClient().giftCards.get('gc_abc123', { expand: ['transactions'] })

      expect(res.id).toBe('gc_abc123')
      expect(url!.searchParams.get('expand')).toBe('transactions')
    })
  })

  describe('create / update / delete', () => {
    it('POSTs the create body verbatim', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(`${API_PREFIX}/gift_cards`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json(sampleGiftCard, { status: 201 })
        }),
      )

      await createTestClient().giftCards.create({ amount: 100, currency: 'USD' })

      expect(body).toEqual({ amount: 100, currency: 'USD' })
    })

    it('PATCHes the update body verbatim', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.patch(`${API_PREFIX}/gift_cards/gc_abc123`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json({ ...sampleGiftCard, expires_at: '2027-01-01T00:00:00Z' })
        }),
      )

      const res = await createTestClient().giftCards.update('gc_abc123', {
        expires_at: '2027-01-01T00:00:00Z',
      })

      expect(body).toEqual({ expires_at: '2027-01-01T00:00:00Z' })
      expect(res.expires_at).toBe('2027-01-01T00:00:00Z')
    })

    it('DELETEs /gift_cards/:id', async () => {
      let hit = false
      server.use(
        http.delete(`${API_PREFIX}/gift_cards/gc_abc123`, () => {
          hit = true
          return new HttpResponse(null, { status: 204 })
        }),
      )

      await expect(createTestClient().giftCards.delete('gc_abc123')).resolves.toBeUndefined()
      expect(hit).toBe(true)
    })
  })
})

describe('giftCardBatches', () => {
  describe('list', () => {
    it('GETs /gift_card_batches and returns paginated data', async () => {
      server.use(
        http.get(`${API_PREFIX}/gift_card_batches`, () =>
          HttpResponse.json(paginated([sampleGiftCardBatch])),
        ),
      )

      const res = await createTestClient().giftCardBatches.list()

      expect(res.data).toHaveLength(1)
      expect(res.data[0]?.id).toBe('gcb_abc123')
    })

    it('wraps Ransack predicates via transformListParams', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/gift_card_batches`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(paginated([]))
        }),
      )

      await createTestClient().giftCardBatches.list({ prefix_cont: 'XMAS' })

      expect(url!.searchParams.get('q[prefix_cont]')).toBe('XMAS')
    })
  })

  describe('get', () => {
    it('GETs /gift_card_batches/:id', async () => {
      server.use(
        http.get(`${API_PREFIX}/gift_card_batches/gcb_abc123`, () =>
          HttpResponse.json(sampleGiftCardBatch),
        ),
      )

      const res = await createTestClient().giftCardBatches.get('gcb_abc123')

      expect(res.id).toBe('gcb_abc123')
      expect(res.codes_count).toBe(50)
    })
  })

  describe('create', () => {
    it('POSTs the create body verbatim', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(`${API_PREFIX}/gift_card_batches`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json(sampleGiftCardBatch, { status: 201 })
        }),
      )

      const res = await createTestClient().giftCardBatches.create({
        prefix: 'XMAS',
        codes_count: 50,
        amount: 25,
        currency: 'USD',
      })

      expect(body).toEqual({ prefix: 'XMAS', codes_count: 50, amount: 25, currency: 'USD' })
      expect(res.prefix).toBe('XMAS')
    })
  })
})
