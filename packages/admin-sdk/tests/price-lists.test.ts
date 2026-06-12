import { HttpResponse, http } from 'msw'
import { describe, expect, it } from 'vitest'
import { API_PREFIX, createTestClient } from './helpers'
import { server } from './mocks/server'

const samplePriceList = {
  id: 'pl_abc123',
  name: 'Wholesale',
  description: null,
  status: 'draft',
  position: 1,
  match_policy: 'all',
  starts_at: null,
  ends_at: null,
  created_at: '2026-05-01T00:00:00Z',
  updated_at: '2026-05-01T00:00:00Z',
  currently_active: false,
  products_count: 0,
  prices_count: 0,
}

describe('priceLists', () => {
  describe('list', () => {
    it('GETs /price_lists and returns paginated data', async () => {
      server.use(
        http.get(`${API_PREFIX}/price_lists`, () =>
          HttpResponse.json({
            data: [samplePriceList],
            meta: { page: 1, limit: 25, count: 1, pages: 1 },
          }),
        ),
      )

      const client = createTestClient()
      const res = await client.priceLists.list()

      expect(res.data).toHaveLength(1)
      expect(res.data[0]?.id).toBe('pl_abc123')
    })

    it('wraps Ransack predicates via transformListParams', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/price_lists`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json({ data: [], meta: { page: 1, limit: 25, count: 0, pages: 0 } })
        }),
      )

      const client = createTestClient()
      await client.priceLists.list({ status_eq: 'active', name_cont: 'whole' })

      expect(url!.searchParams.get('q[status_eq]')).toBe('active')
      expect(url!.searchParams.get('q[name_cont]')).toBe('whole')
    })
  })

  describe('create', () => {
    it('POSTs the params verbatim', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(`${API_PREFIX}/price_lists`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json(samplePriceList, { status: 201 })
        }),
      )

      const client = createTestClient()
      await client.priceLists.create({ name: 'Wholesale', match_policy: 'all' })

      expect(body).toEqual({ name: 'Wholesale', match_policy: 'all' })
    })
  })

  describe('activate / deactivate', () => {
    it('PATCHes /activate', async () => {
      let hit = false
      server.use(
        http.patch(`${API_PREFIX}/price_lists/pl_abc123/activate`, () => {
          hit = true
          return HttpResponse.json({ ...samplePriceList, status: 'active', currently_active: true })
        }),
      )

      const client = createTestClient()
      const res = await client.priceLists.activate('pl_abc123')

      expect(hit).toBe(true)
      expect(res.status).toBe('active')
    })

    it('PATCHes /deactivate', async () => {
      server.use(
        http.patch(`${API_PREFIX}/price_lists/pl_abc123/deactivate`, () =>
          HttpResponse.json({ ...samplePriceList, status: 'inactive' }),
        ),
      )

      const client = createTestClient()
      const res = await client.priceLists.deactivate('pl_abc123')

      expect(res.status).toBe('inactive')
    })
  })

  describe('update with product_ids', () => {
    it('PATCHes the desired product set as part of the regular update payload', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.patch(`${API_PREFIX}/price_lists/pl_abc123`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json({
            ...samplePriceList,
            product_ids: ['prod_a', 'prod_b'],
          })
        }),
      )

      const client = createTestClient()
      const res = await client.priceLists.update('pl_abc123', {
        name: 'Wholesale',
        product_ids: ['prod_a', 'prod_b'],
      })

      // Membership reconciliation is part of the same PATCH that carries
      // name / description / rules — there are no separate endpoints.
      expect(body).toEqual({ name: 'Wholesale', product_ids: ['prod_a', 'prod_b'] })
      expect(res).toMatchObject({ product_ids: ['prod_a', 'prod_b'] })
    })
  })

  describe('update with prices', () => {
    it('PATCHes price overrides as part of the regular update payload', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.patch(`${API_PREFIX}/price_lists/pl_abc123`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json(samplePriceList)
        }),
      )

      const client = createTestClient()
      await client.priceLists.update('pl_abc123', {
        prices: [
          { id: 'price_x', variant_id: 'variant_x', currency: 'USD', amount: '12.50' },
          {
            id: 'price_y',
            variant_id: 'variant_y',
            currency: 'USD',
            amount: null,
            compare_at_amount: '15.00',
          },
        ],
      })

      // Membership / rules / individual price overrides all reconcile in
      // the same PATCH — there's no separate bulk endpoint.
      expect((body as { prices: unknown[] }).prices).toHaveLength(2)
    })
  })

  // Rules themselves aren't a separate REST resource — they ride along
  // on the price list's `update` payload. The one exception is the
  // discovery endpoint below, which the SPA hits to build the "Add rule"
  // picker without hard-coding subclass labels.
  describe('ruleTypes', () => {
    it('lists rule types with preference schema', async () => {
      server.use(
        http.get(`${API_PREFIX}/price_lists/price_rule_types`, () =>
          HttpResponse.json({
            data: [
              {
                type: 'volume_rule',
                label: 'Volume Rule',
                description: 'Apply pricing based on quantity purchased',
                preference_schema: [{ key: 'min_quantity', type: 'integer', default: 1 }],
              },
            ],
          }),
        ),
      )

      const client = createTestClient()
      const res = await client.priceLists.ruleTypes()

      expect(res.data).toHaveLength(1)
      expect(res.data[0]?.type).toBe('volume_rule')
    })
  })
})
