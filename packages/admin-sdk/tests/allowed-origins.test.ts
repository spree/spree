import { HttpResponse, http } from 'msw'
import { describe, expect, it } from 'vitest'
import { API_PREFIX, createTestClient, paginated } from './helpers'
import { server } from './mocks/server'

const sampleAllowedOrigin = {
  id: 'ao_abc123',
  origin: 'https://app.example.com',
  created_at: '2026-05-01T00:00:00Z',
  updated_at: '2026-05-01T00:00:00Z',
}

describe('allowedOrigins', () => {
  describe('list', () => {
    it('GETs /allowed_origins and returns paginated data', async () => {
      server.use(
        http.get(`${API_PREFIX}/allowed_origins`, () =>
          HttpResponse.json(paginated([sampleAllowedOrigin])),
        ),
      )

      const res = await createTestClient().allowedOrigins.list()

      expect(res.data).toHaveLength(1)
      expect(res.data[0]?.id).toBe('ao_abc123')
    })

    it('wraps Ransack predicates via transformListParams', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/allowed_origins`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(paginated([]))
        }),
      )

      await createTestClient().allowedOrigins.list({ origin_cont: 'example' })

      expect(url!.searchParams.get('q[origin_cont]')).toBe('example')
    })
  })

  describe('get', () => {
    it('GETs /allowed_origins/:id and forwards expand params', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/allowed_origins/ao_abc123`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(sampleAllowedOrigin)
        }),
      )

      const res = await createTestClient().allowedOrigins.get('ao_abc123', { expand: ['store'] })

      expect(res.id).toBe('ao_abc123')
      expect(url!.searchParams.get('expand')).toBe('store')
    })
  })

  describe('create / update / delete', () => {
    it('POSTs the create body verbatim', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(`${API_PREFIX}/allowed_origins`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json(sampleAllowedOrigin, { status: 201 })
        }),
      )

      const res = await createTestClient().allowedOrigins.create({
        origin: 'https://app.example.com',
      })

      expect(body).toEqual({ origin: 'https://app.example.com' })
      expect(res.id).toBe('ao_abc123')
    })

    it('PATCHes the update body verbatim', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.patch(`${API_PREFIX}/allowed_origins/ao_abc123`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json({ ...sampleAllowedOrigin, origin: 'https://admin.example.com' })
        }),
      )

      const res = await createTestClient().allowedOrigins.update('ao_abc123', {
        origin: 'https://admin.example.com',
      })

      expect(body).toEqual({ origin: 'https://admin.example.com' })
      expect(res.origin).toBe('https://admin.example.com')
    })

    it('DELETEs /allowed_origins/:id', async () => {
      let hit = false
      server.use(
        http.delete(`${API_PREFIX}/allowed_origins/ao_abc123`, () => {
          hit = true
          return new HttpResponse(null, { status: 204 })
        }),
      )

      await expect(createTestClient().allowedOrigins.delete('ao_abc123')).resolves.toBeUndefined()
      expect(hit).toBe(true)
    })
  })
})
