import { HttpResponse, http } from 'msw'
import { describe, expect, it } from 'vitest'
import { API_PREFIX, createTestClient, paginated } from './helpers'
import { server } from './mocks/server'

const sampleRole = {
  id: 'role_abc123',
  name: 'admin',
  created_at: '2026-05-01T00:00:00Z',
  updated_at: '2026-05-01T00:00:00Z',
}

const sampleCategory = {
  id: 'cat_abc123',
  name: 'Apparel',
  permalink: 'apparel',
}

const sampleVariant = {
  id: 'variant_abc123',
  sku: 'SKU-1',
  price: '19.99',
}

const sampleCountry = {
  id: 'country_abc123',
  iso: 'US',
  name: 'United States',
}

const sampleStoreCreditCategory = {
  id: 'scc_abc123',
  name: 'Refund',
}

describe('roles', () => {
  describe('list', () => {
    it('GETs /roles and returns paginated data', async () => {
      server.use(http.get(`${API_PREFIX}/roles`, () => HttpResponse.json(paginated([sampleRole]))))

      const res = await createTestClient().roles.list()

      expect(res.data).toHaveLength(1)
      expect(res.data[0]?.id).toBe('role_abc123')
    })

    it('wraps Ransack predicates via transformListParams', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/roles`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(paginated([]))
        }),
      )

      await createTestClient().roles.list({ name_cont: 'admin' })

      expect(url!.searchParams.get('q[name_cont]')).toBe('admin')
    })
  })

  describe('get', () => {
    it('GETs /roles/:id and forwards expand params', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/roles/role_abc123`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(sampleRole)
        }),
      )

      const res = await createTestClient().roles.get('role_abc123', { expand: ['permissions'] })

      expect(res.id).toBe('role_abc123')
      expect(url!.searchParams.get('expand')).toBe('permissions')
    })
  })
})

describe('categories', () => {
  describe('list', () => {
    it('GETs /categories and returns paginated data', async () => {
      server.use(
        http.get(`${API_PREFIX}/categories`, () => HttpResponse.json(paginated([sampleCategory]))),
      )

      const res = await createTestClient().categories.list()

      expect(res.data).toHaveLength(1)
      expect(res.data[0]?.id).toBe('cat_abc123')
    })

    it('wraps Ransack predicates via transformListParams', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/categories`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(paginated([]))
        }),
      )

      await createTestClient().categories.list({ name_cont: 'apparel' })

      expect(url!.searchParams.get('q[name_cont]')).toBe('apparel')
    })
  })
})

describe('variants', () => {
  describe('list', () => {
    it('GETs /variants and returns paginated data', async () => {
      server.use(
        http.get(`${API_PREFIX}/variants`, () => HttpResponse.json(paginated([sampleVariant]))),
      )

      const res = await createTestClient().variants.list()

      expect(res.data).toHaveLength(1)
      expect(res.data[0]?.id).toBe('variant_abc123')
    })

    it('wraps Ransack predicates via transformListParams', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/variants`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(paginated([]))
        }),
      )

      await createTestClient().variants.list({ sku_cont: 'SKU' })

      expect(url!.searchParams.get('q[sku_cont]')).toBe('SKU')
    })
  })

  describe('get', () => {
    it('GETs /variants/:id and forwards expand params', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/variants/variant_abc123`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(sampleVariant)
        }),
      )

      const res = await createTestClient().variants.get('variant_abc123', {
        expand: ['stock_items'],
      })

      expect(res.id).toBe('variant_abc123')
      expect(url!.searchParams.get('expand')).toBe('stock_items')
    })
  })
})

describe('countries', () => {
  describe('list', () => {
    it('GETs /countries and returns paginated data', async () => {
      server.use(
        http.get(`${API_PREFIX}/countries`, () => HttpResponse.json(paginated([sampleCountry]))),
      )

      const res = await createTestClient().countries.list()

      expect(res.data).toHaveLength(1)
      expect(res.data[0]?.id).toBe('country_abc123')
    })

    it('wraps Ransack predicates via transformListParams', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/countries`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(paginated([]))
        }),
      )

      await createTestClient().countries.list({ name_cont: 'United' })

      expect(url!.searchParams.get('q[name_cont]')).toBe('United')
    })
  })

  describe('get', () => {
    it('GETs /countries/:iso and forwards expand=states', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/countries/US`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(sampleCountry)
        }),
      )

      const res = await createTestClient().countries.get('US', { expand: ['states'] })

      expect(res.iso).toBe('US')
      expect(url!.searchParams.get('expand')).toBe('states')
    })
  })
})

describe('storeCreditCategories', () => {
  describe('list', () => {
    it('GETs /store_credit_categories and returns paginated data', async () => {
      server.use(
        http.get(`${API_PREFIX}/store_credit_categories`, () =>
          HttpResponse.json(paginated([sampleStoreCreditCategory])),
        ),
      )

      const res = await createTestClient().storeCreditCategories.list()

      expect(res.data).toHaveLength(1)
      expect(res.data[0]?.id).toBe('scc_abc123')
    })

    it('wraps Ransack predicates via transformListParams', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/store_credit_categories`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(paginated([]))
        }),
      )

      await createTestClient().storeCreditCategories.list({ name_cont: 'Refund' })

      expect(url!.searchParams.get('q[name_cont]')).toBe('Refund')
    })
  })

  describe('get', () => {
    it('GETs /store_credit_categories/:id', async () => {
      server.use(
        http.get(`${API_PREFIX}/store_credit_categories/scc_abc123`, () =>
          HttpResponse.json(sampleStoreCreditCategory),
        ),
      )

      const res = await createTestClient().storeCreditCategories.get('scc_abc123')

      expect(res.id).toBe('scc_abc123')
    })
  })
})

describe('tags', () => {
  describe('list', () => {
    it('GETs /tags and returns the tag list', async () => {
      server.use(
        http.get(`${API_PREFIX}/tags`, () => HttpResponse.json({ data: [{ name: 'vip' }] })),
      )

      const res = await createTestClient().tags.list({ taggable_type: 'Spree::Customer' })

      expect(res.data).toHaveLength(1)
      expect(res.data[0]?.name).toBe('vip')
    })

    it('forwards taggable_type + q filter params', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/tags`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json({ data: [] })
        }),
      )

      await createTestClient().tags.list({ taggable_type: 'Spree::Customer', q: 'vi' })

      expect(url!.searchParams.get('taggable_type')).toBe('Spree::Customer')
      expect(url!.searchParams.get('q')).toBe('vi')
    })
  })
})
