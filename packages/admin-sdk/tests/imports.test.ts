import { HttpResponse, http } from 'msw'
import { describe, expect, it } from 'vitest'
import { API_PREFIX, createTestClient } from './helpers'
import { server } from './mocks/server'

const sampleImport = {
  id: 'imp_abc123',
  number: 'IM000001',
  type: 'Spree::Imports::Products',
  status: 'mapping',
  rows_count: 0,
  completed_rows_count: 0,
  failed_rows_count: 0,
  owner_type: 'Spree::Store',
  owner_id: 'store_1',
  user_id: 'usr_admin',
  processing_errors: null,
  preferred_delimiter: ',',
  schema_fields: [
    { name: 'slug', label: 'Slug', required: true },
    { name: 'price', label: 'Price', required: true },
  ],
  csv_headers: ['Product Handle', 'price'],
  sample_row: { 'Product Handle': 'widget', price: '10.00' },
  mappings: [
    { id: 'immap_1', schema_field: 'slug', file_column: null, required: true },
    { id: 'immap_2', schema_field: 'price', file_column: 'price', required: true },
  ],
  created_at: '2026-07-10T12:00:00Z',
  updated_at: '2026-07-10T12:00:00Z',
}

describe('imports', () => {
  describe('list', () => {
    it('GETs /imports and returns paginated data', async () => {
      server.use(
        http.get(`${API_PREFIX}/imports`, () =>
          HttpResponse.json({
            data: [sampleImport],
            meta: { page: 1, limit: 25, count: 1, pages: 1 },
          }),
        ),
      )

      const client = createTestClient()
      const res = await client.imports.list()

      expect(res.data).toHaveLength(1)
      expect(res.data[0]?.id).toBe('imp_abc123')
    })

    it('passes ListParams through transformListParams (q[...] wrapping)', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/imports`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json({ data: [], meta: { page: 1, limit: 25, count: 0, pages: 0 } })
        }),
      )

      const client = createTestClient()
      await client.imports.list({ status_eq: 'completed' })

      expect(url!.searchParams.get('q[status_eq]')).toBe('completed')
    })
  })

  describe('get', () => {
    it('GETs /imports/:id', async () => {
      server.use(
        http.get(`${API_PREFIX}/imports/imp_abc123`, () =>
          HttpResponse.json({ ...sampleImport, status: 'processing', rows_count: 100 }),
        ),
      )

      const client = createTestClient()
      const res = await client.imports.get('imp_abc123')

      expect(res.status).toBe('processing')
      expect(res.rows_count).toBe(100)
    })
  })

  describe('create', () => {
    it('POSTs /imports with type, attachment signed id and delimiter', async () => {
      let body: unknown = null
      server.use(
        http.post(`${API_PREFIX}/imports`, async ({ request }) => {
          body = await request.json()
          return HttpResponse.json(sampleImport, { status: 201 })
        }),
      )

      const client = createTestClient()
      const res = await client.imports.create({
        type: 'Spree::Imports::Products',
        attachment: 'signed-blob-id',
        preferred_delimiter: ';',
      })

      expect(body).toEqual({
        type: 'Spree::Imports::Products',
        attachment: 'signed-blob-id',
        preferred_delimiter: ';',
      })
      expect(res.status).toBe('mapping')
      expect(res.mappings).toHaveLength(2)
    })
  })

  describe('completeMapping', () => {
    it('PATCHes /imports/:id/complete_mapping with submitted mappings', async () => {
      let body: unknown = null
      server.use(
        http.patch(`${API_PREFIX}/imports/imp_abc123/complete_mapping`, async ({ request }) => {
          body = await request.json()
          return HttpResponse.json({ ...sampleImport, status: 'completed_mapping' })
        }),
      )

      const client = createTestClient()
      const res = await client.imports.completeMapping('imp_abc123', {
        mappings: [{ schema_field: 'slug', file_column: 'Product Handle' }],
      })

      expect(body).toEqual({
        mappings: [{ schema_field: 'slug', file_column: 'Product Handle' }],
      })
      expect(res.status).toBe('completed_mapping')
    })

    it('sends an empty body when mappings are omitted', async () => {
      let body: unknown = null
      server.use(
        http.patch(`${API_PREFIX}/imports/imp_abc123/complete_mapping`, async ({ request }) => {
          body = await request.json()
          return HttpResponse.json({ ...sampleImport, status: 'completed_mapping' })
        }),
      )

      const client = createTestClient()
      await client.imports.completeMapping('imp_abc123')

      expect(body).toEqual({})
    })
  })

  describe('retryFailedRows', () => {
    it('PATCHes /imports/:id/retry_failed_rows', async () => {
      server.use(
        http.patch(`${API_PREFIX}/imports/imp_abc123/retry_failed_rows`, () =>
          HttpResponse.json({ ...sampleImport, status: 'processing' }),
        ),
      )

      const client = createTestClient()
      const res = await client.imports.retryFailedRows('imp_abc123')

      expect(res.status).toBe('processing')
    })
  })

  describe('delete', () => {
    it('DELETEs /imports/:id', async () => {
      let called = false
      server.use(
        http.delete(`${API_PREFIX}/imports/imp_abc123`, () => {
          called = true
          return new HttpResponse(null, { status: 204 })
        }),
      )

      const client = createTestClient()
      await client.imports.delete('imp_abc123')

      expect(called).toBe(true)
    })
  })

  describe('rows.list', () => {
    it('GETs /imports/:id/rows with a status filter', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/imports/imp_abc123/rows`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json({
            data: [
              {
                id: 'imrow_1',
                import_id: 'imp_abc123',
                row_number: 2,
                status: 'failed',
                validation_errors: "Price can't be blank",
                item_type: null,
                item_id: null,
                data: { slug: 'widget', price: '' },
                created_at: '2026-07-10T12:00:00Z',
                updated_at: '2026-07-10T12:00:00Z',
              },
            ],
            meta: { page: 1, limit: 25, count: 1, pages: 1 },
          })
        }),
      )

      const client = createTestClient()
      const res = await client.imports.rows.list('imp_abc123', { status_eq: 'failed' })

      expect(url!.searchParams.get('q[status_eq]')).toBe('failed')
      expect(res.data[0]?.validation_errors).toBe("Price can't be blank")
      expect(res.data[0]?.data).toEqual({ slug: 'widget', price: '' })
    })
  })
})
