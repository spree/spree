import { HttpResponse, http } from 'msw'
import { describe, expect, it } from 'vitest'
import { API_PREFIX, createTestClient, paginated } from './helpers'
import { server } from './mocks/server'

const sampleTaxCategory = {
  id: 'tc_abc123',
  name: 'Clothing',
  tax_code: 'CLOTH',
  description: null,
  is_default: false,
  created_at: '2026-05-01T00:00:00Z',
  updated_at: '2026-05-01T00:00:00Z',
}

describe('taxCategories', () => {
  describe('list', () => {
    it('GETs /tax_categories and returns paginated data', async () => {
      server.use(
        http.get(`${API_PREFIX}/tax_categories`, () =>
          HttpResponse.json(paginated([sampleTaxCategory])),
        ),
      )

      const res = await createTestClient().taxCategories.list()

      expect(res.data).toHaveLength(1)
      expect(res.data[0]?.id).toBe('tc_abc123')
    })

    it('wraps Ransack predicates via transformListParams', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/tax_categories`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(paginated([]))
        }),
      )

      await createTestClient().taxCategories.list({ name_cont: 'cloth', is_default_eq: true })

      expect(url!.searchParams.get('q[name_cont]')).toBe('cloth')
      expect(url!.searchParams.get('q[is_default_eq]')).toBe('true')
    })
  })

  describe('get', () => {
    it('GETs /tax_categories/:id and forwards expand params', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/tax_categories/tc_abc123`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(sampleTaxCategory)
        }),
      )

      const res = await createTestClient().taxCategories.get('tc_abc123', { expand: ['tax_rates'] })

      expect(res.id).toBe('tc_abc123')
      expect(url!.searchParams.get('expand')).toBe('tax_rates')
    })
  })

  describe('create / update / delete', () => {
    it('POSTs the create body verbatim', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(`${API_PREFIX}/tax_categories`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json(sampleTaxCategory, { status: 201 })
        }),
      )

      await createTestClient().taxCategories.create({ name: 'Clothing', tax_code: 'CLOTH' })

      expect(body).toEqual({ name: 'Clothing', tax_code: 'CLOTH' })
    })

    it('PATCHes the update body verbatim', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.patch(`${API_PREFIX}/tax_categories/tc_abc123`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json({ ...sampleTaxCategory, is_default: true })
        }),
      )

      const res = await createTestClient().taxCategories.update('tc_abc123', { is_default: true })

      expect(body).toEqual({ is_default: true })
      expect(res.is_default).toBe(true)
    })

    it('DELETEs /tax_categories/:id', async () => {
      let hit = false
      server.use(
        http.delete(`${API_PREFIX}/tax_categories/tc_abc123`, () => {
          hit = true
          return new HttpResponse(null, { status: 204 })
        }),
      )

      await expect(createTestClient().taxCategories.delete('tc_abc123')).resolves.toBeUndefined()
      expect(hit).toBe(true)
    })
  })
})
