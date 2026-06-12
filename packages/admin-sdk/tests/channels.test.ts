import { HttpResponse, http } from 'msw'
import { describe, expect, it } from 'vitest'
import { API_PREFIX, createTestClient, paginated } from './helpers'
import { server } from './mocks/server'

const sampleChannel = {
  id: 'chan_abc123',
  name: 'Online Store',
  default: true,
  created_at: '2026-05-01T00:00:00Z',
  updated_at: '2026-05-01T00:00:00Z',
}

describe('channels', () => {
  describe('list', () => {
    it('GETs /channels and returns paginated data', async () => {
      server.use(
        http.get(`${API_PREFIX}/channels`, () => HttpResponse.json(paginated([sampleChannel]))),
      )

      const res = await createTestClient().channels.list()

      expect(res.data).toHaveLength(1)
      expect(res.data[0]?.id).toBe('chan_abc123')
    })

    it('wraps Ransack predicates via transformListParams', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/channels`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(paginated([]))
        }),
      )

      await createTestClient().channels.list({ name_cont: 'store', default_eq: true })

      expect(url!.searchParams.get('q[name_cont]')).toBe('store')
      expect(url!.searchParams.get('q[default_eq]')).toBe('true')
    })
  })

  describe('get', () => {
    it('GETs /channels/:id and forwards expand params', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/channels/chan_abc123`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(sampleChannel)
        }),
      )

      const res = await createTestClient().channels.get('chan_abc123', { expand: ['products'] })

      expect(res.id).toBe('chan_abc123')
      expect(url!.searchParams.get('expand')).toBe('products')
    })
  })

  describe('create / update / delete', () => {
    it('POSTs the create body verbatim', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(`${API_PREFIX}/channels`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json(sampleChannel, { status: 201 })
        }),
      )

      await createTestClient().channels.create({ name: 'Online Store', default: true })

      expect(body).toEqual({ name: 'Online Store', default: true })
    })

    it('PATCHes the update body verbatim', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.patch(`${API_PREFIX}/channels/chan_abc123`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json({ ...sampleChannel, name: 'Retail' })
        }),
      )

      const res = await createTestClient().channels.update('chan_abc123', { name: 'Retail' })

      expect(body).toEqual({ name: 'Retail' })
      expect(res.name).toBe('Retail')
    })

    it('DELETEs /channels/:id', async () => {
      let hit = false
      server.use(
        http.delete(`${API_PREFIX}/channels/chan_abc123`, () => {
          hit = true
          return new HttpResponse(null, { status: 204 })
        }),
      )

      await expect(createTestClient().channels.delete('chan_abc123')).resolves.toBeUndefined()
      expect(hit).toBe(true)
    })
  })

  describe('addProducts / removeProducts', () => {
    it('POSTs /channels/:id/add_products with the params verbatim', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(`${API_PREFIX}/channels/chan_abc123/add_products`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json({ product_count: 2 })
        }),
      )

      const res = await createTestClient().channels.addProducts('chan_abc123', {
        product_ids: ['prod_a', 'prod_b'],
      })

      expect(body).toEqual({ product_ids: ['prod_a', 'prod_b'] })
      expect(res.product_count).toBe(2)
    })

    it('POSTs /channels/:id/remove_products with the params verbatim', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(`${API_PREFIX}/channels/chan_abc123/remove_products`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json({ product_count: 1 })
        }),
      )

      const res = await createTestClient().channels.removeProducts('chan_abc123', {
        product_ids: ['prod_a'],
      })

      expect(body).toEqual({ product_ids: ['prod_a'] })
      expect(res.product_count).toBe(1)
    })
  })
})
