import { HttpResponse, http } from 'msw'
import { describe, expect, it } from 'vitest'
import { createAdminClient } from '../src'
import { server } from './mocks/server'

const BASE_URL = 'https://demo.spreecommerce.org'
const API_PREFIX = `${BASE_URL}/api/v3/admin`

const sampleExport = {
  id: 'exp_abc123',
  number: 'EF000001',
  type: 'Spree::Exports::Products',
  format: 'csv',
  user_id: 'usr_admin',
  done: false,
  filename: null,
  byte_size: null,
  download_url: null,
  created_at: '2026-05-07T12:00:00Z',
  updated_at: '2026-05-07T12:00:00Z',
}

describe('exports', () => {
  describe('list', () => {
    it('GETs /exports and returns paginated data', async () => {
      server.use(
        http.get(`${API_PREFIX}/exports`, () =>
          HttpResponse.json({
            data: [sampleExport],
            meta: { page: 1, limit: 25, count: 1, pages: 1 },
          }),
        ),
      )

      const client = createAdminClient({ baseUrl: BASE_URL })
      const res = await client.exports.list()

      expect(res.data).toHaveLength(1)
      expect(res.data[0]?.id).toBe('exp_abc123')
    })

    it('passes ListParams through transformListParams (q[...] wrapping)', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/exports`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json({ data: [], meta: { page: 1, limit: 25, count: 0, pages: 0 } })
        }),
      )

      const client = createAdminClient({ baseUrl: BASE_URL })
      await client.exports.list({ type_eq: 'Spree::Exports::Products' })

      // transformListParams wraps free predicates in q[...]
      expect(url!.searchParams.get('q[type_eq]')).toBe('Spree::Exports::Products')
    })
  })

  describe('get', () => {
    it('GETs /exports/:id', async () => {
      server.use(
        http.get(`${API_PREFIX}/exports/exp_abc123`, () =>
          HttpResponse.json({
            ...sampleExport,
            done: true,
            download_url: '/api/v3/admin/exports/exp_abc123/download',
          }),
        ),
      )

      const client = createAdminClient({ baseUrl: BASE_URL })
      const res = await client.exports.get('exp_abc123')

      expect(res.done).toBe(true)
      expect(res.download_url).toBe('/api/v3/admin/exports/exp_abc123/download')
    })
  })

  describe('create', () => {
    it('POSTs the type and search_params verbatim', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(`${API_PREFIX}/exports`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json(sampleExport, { status: 201 })
        }),
      )

      const client = createAdminClient({ baseUrl: BASE_URL })
      const res = await client.exports.create({
        type: 'Spree::Exports::Products',
        search_params: { name_cont: 'shirt', price_gt: 10 },
      })

      expect(body).toEqual({
        type: 'Spree::Exports::Products',
        search_params: { name_cont: 'shirt', price_gt: 10 },
      })
      expect(res.id).toBe('exp_abc123')
    })

    it('supports record_selection: "all" for unfiltered exports', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(`${API_PREFIX}/exports`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json(sampleExport, { status: 201 })
        }),
      )

      const client = createAdminClient({ baseUrl: BASE_URL })
      await client.exports.create({
        type: 'Spree::Exports::Orders',
        record_selection: 'all',
      })

      expect(body).toEqual({
        type: 'Spree::Exports::Orders',
        record_selection: 'all',
      })
    })
  })

  describe('delete', () => {
    it('DELETEs /exports/:id', async () => {
      let hit = false
      server.use(
        http.delete(`${API_PREFIX}/exports/exp_abc123`, () => {
          hit = true
          return new HttpResponse(null, { status: 204 })
        }),
      )

      const client = createAdminClient({ baseUrl: BASE_URL })
      await client.exports.delete('exp_abc123')

      expect(hit).toBe(true)
    })
  })
})
