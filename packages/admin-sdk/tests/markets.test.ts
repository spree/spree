import { HttpResponse, http } from 'msw'
import { describe, expect, it } from 'vitest'
import { API_PREFIX, createTestClient, paginated } from './helpers'
import { server } from './mocks/server'

const sampleMarket = {
  id: 'market_abc123',
  name: 'European Union',
  currency: 'EUR',
  default: false,
  created_at: '2026-05-01T00:00:00Z',
  updated_at: '2026-05-01T00:00:00Z',
}

describe('markets', () => {
  describe('list', () => {
    it('GETs /markets and returns paginated data', async () => {
      server.use(
        http.get(`${API_PREFIX}/markets`, () => HttpResponse.json(paginated([sampleMarket]))),
      )

      const res = await createTestClient().markets.list()

      expect(res.data).toHaveLength(1)
      expect(res.data[0]?.id).toBe('market_abc123')
    })

    it('wraps Ransack predicates via transformListParams', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/markets`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(paginated([]))
        }),
      )

      await createTestClient().markets.list({ name_cont: 'euro', currency_eq: 'EUR' })

      expect(url!.searchParams.get('q[name_cont]')).toBe('euro')
      expect(url!.searchParams.get('q[currency_eq]')).toBe('EUR')
    })
  })

  describe('get', () => {
    it('GETs /markets/:id and forwards expand params', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/markets/market_abc123`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(sampleMarket)
        }),
      )

      const res = await createTestClient().markets.get('market_abc123', { expand: ['countries'] })

      expect(res.id).toBe('market_abc123')
      expect(url!.searchParams.get('expand')).toBe('countries')
    })
  })

  describe('create / update / delete', () => {
    it('POSTs the create body verbatim', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(`${API_PREFIX}/markets`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json(sampleMarket, { status: 201 })
        }),
      )

      await createTestClient().markets.create({ name: 'European Union', currency: 'EUR' })

      expect(body).toEqual({ name: 'European Union', currency: 'EUR' })
    })

    it('PATCHes the update body verbatim', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.patch(`${API_PREFIX}/markets/market_abc123`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json({ ...sampleMarket, name: 'Eurozone' })
        }),
      )

      const res = await createTestClient().markets.update('market_abc123', { name: 'Eurozone' })

      expect(body).toEqual({ name: 'Eurozone' })
      expect(res.name).toBe('Eurozone')
    })

    it('DELETEs /markets/:id', async () => {
      let hit = false
      server.use(
        http.delete(`${API_PREFIX}/markets/market_abc123`, () => {
          hit = true
          return new HttpResponse(null, { status: 204 })
        }),
      )

      await expect(createTestClient().markets.delete('market_abc123')).resolves.toBeUndefined()
      expect(hit).toBe(true)
    })
  })
})
