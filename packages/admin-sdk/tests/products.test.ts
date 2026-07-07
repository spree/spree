import { HttpResponse, http } from 'msw'
import { describe, expect, it } from 'vitest'
import { API_PREFIX, createTestClient, paginated } from './helpers'
import { server } from './mocks/server'

const sampleProduct = {
  id: 'prod_abc123',
  name: 'T-Shirt',
  slug: 't-shirt',
  status: 'active',
  created_at: '2026-05-01T00:00:00Z',
  updated_at: '2026-05-01T00:00:00Z',
}

describe('products', () => {
  describe('list / get', () => {
    it('GETs /products with Ransack filters + sort', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/products`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(paginated([sampleProduct]))
        }),
      )

      const res = await createTestClient().products.list({
        status_eq: 'active',
        sort: '-created_at',
      })

      expect(res.data[0]?.id).toBe('prod_abc123')
      expect(url!.searchParams.get('q[status_eq]')).toBe('active')
      expect(url!.searchParams.get('sort')).toBe('-created_at')
    })

    it('GETs /products/:id with expand', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/products/prod_abc123`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(sampleProduct)
        }),
      )

      await createTestClient().products.get('prod_abc123', { expand: ['variants', 'images'] })

      expect(url!.searchParams.get('expand')).toBe('variants,images')
    })
  })

  describe('create / update / delete', () => {
    it('POSTs the create body verbatim', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(`${API_PREFIX}/products`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json(sampleProduct, { status: 201 })
        }),
      )

      await createTestClient().products.create({ name: 'T-Shirt', status: 'active' })

      expect(body).toEqual({ name: 'T-Shirt', status: 'active' })
    })

    it('PATCHes the update body verbatim', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.patch(`${API_PREFIX}/products/prod_abc123`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json({ ...sampleProduct, name: 'Hoodie' })
        }),
      )

      const res = await createTestClient().products.update('prod_abc123', { name: 'Hoodie' })

      expect(body).toEqual({ name: 'Hoodie' })
      expect(res.name).toBe('Hoodie')
    })

    it('DELETEs /products/:id', async () => {
      let hit = false
      server.use(
        http.delete(`${API_PREFIX}/products/prod_abc123`, () => {
          hit = true
          return new HttpResponse(null, { status: 204 })
        }),
      )

      await expect(createTestClient().products.delete('prod_abc123')).resolves.toBeUndefined()
      expect(hit).toBe(true)
    })
  })

  describe('clone', () => {
    it('POSTs /products/:id/clone and returns the new draft', async () => {
      server.use(
        http.post(`${API_PREFIX}/products/prod_abc123/clone`, () =>
          HttpResponse.json(
            { ...sampleProduct, id: 'prod_copy', name: 'COPY OF T-Shirt', status: 'draft' },
            {
              status: 201,
            },
          ),
        ),
      )

      const res = await createTestClient().products.clone('prod_abc123')

      expect(res.id).toBe('prod_copy')
      expect(res.status).toBe('draft')
    })
  })

  describe('readiness', () => {
    it('GETs /products/:id/readiness and unwraps the data envelope', async () => {
      server.use(
        http.get(`${API_PREFIX}/products/prod_abc123/readiness`, () =>
          HttpResponse.json({
            data: {
              ready: false,
              checks: [
                { key: 'status', ready: true, message: null },
                { key: 'price:EUR', ready: false, message: 'No price set in EUR (market "EU")' },
              ],
            },
          }),
        ),
      )

      const res = await createTestClient().products.readiness('prod_abc123')

      expect(res.ready).toBe(false)
      expect(res.checks).toHaveLength(2)
      expect(res.checks[1]).toEqual({
        key: 'price:EUR',
        ready: false,
        message: 'No price set in EUR (market "EU")',
      })
    })
  })

  describe('bulk operations', () => {
    it('POSTs /bulk_status_update with ids + status', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(`${API_PREFIX}/products/bulk_status_update`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json({ product_count: 2, status: 'archived' })
        }),
      )

      const res = await createTestClient().products.bulkStatusUpdate({
        ids: ['prod_a', 'prod_b'],
        status: 'archived',
      })

      expect(body).toEqual({ ids: ['prod_a', 'prod_b'], status: 'archived' })
      expect(res.product_count).toBe(2)
    })

    it('POSTs /bulk_add_to_categories with ids + category_ids', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(`${API_PREFIX}/products/bulk_add_to_categories`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json({ product_count: 1, category_count: 2 })
        }),
      )

      await createTestClient().products.bulkAddToCategories({
        ids: ['prod_a'],
        category_ids: ['cat_1', 'cat_2'],
      })

      expect(body).toEqual({ ids: ['prod_a'], category_ids: ['cat_1', 'cat_2'] })
    })

    it('POSTs /bulk_add_to_channels with ids + channel_ids', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(`${API_PREFIX}/products/bulk_add_to_channels`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json({ product_count: 1, channel_count: 1 })
        }),
      )

      await createTestClient().products.bulkAddToChannels({
        ids: ['prod_a'],
        channel_ids: ['chan_1'],
      })

      expect(body).toEqual({ ids: ['prod_a'], channel_ids: ['chan_1'] })
    })

    it('DELETEs /bulk_destroy with ids in the body', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.delete(`${API_PREFIX}/products/bulk_destroy`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json({ product_count: 2 })
        }),
      )

      const res = await createTestClient().products.bulkDestroy({ ids: ['prod_a', 'prod_b'] })

      expect(body).toEqual({ ids: ['prod_a', 'prod_b'] })
      expect(res.product_count).toBe(2)
    })
  })
})

describe('prices', () => {
  const samplePrice = { id: 'price_1', amount: '12.50', currency: 'USD', variant_id: 'variant_1' }

  describe('list', () => {
    it('GETs /prices filtering by price_list_id', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/prices`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(paginated([samplePrice]))
        }),
      )

      await createTestClient().prices.list({ price_list_id_eq: 'pl_1' })

      expect(url!.searchParams.get('q[price_list_id_eq]')).toBe('pl_1')
    })
  })

  describe('bulkUpsert', () => {
    it('POSTs /prices/bulk_upsert with a prices array and returns the count', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(`${API_PREFIX}/prices/bulk_upsert`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json({ price_count: 2 })
        }),
      )

      const res = await createTestClient().prices.bulkUpsert({
        prices: [
          { variant_id: 'variant_1', currency: 'USD', amount: '12.50' },
          { variant_id: 'variant_2', currency: 'USD', amount: '9.99', price_list_id: 'pl_1' },
        ],
      })

      expect((body as { prices: unknown[] }).prices).toHaveLength(2)
      expect(res.price_count).toBe(2)
    })
  })

  describe('bulkDestroy', () => {
    it('DELETEs /prices/bulk_destroy with ids', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.delete(`${API_PREFIX}/prices/bulk_destroy`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json({ price_count: 1 })
        }),
      )

      await createTestClient().prices.bulkDestroy({ ids: ['price_1'] })

      expect(body).toEqual({ ids: ['price_1'] })
    })
  })
})
