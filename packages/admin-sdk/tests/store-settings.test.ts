import { HttpResponse, http } from 'msw'
import { describe, expect, it } from 'vitest'
import { API_PREFIX, createTestClient } from './helpers'
import { server } from './mocks/server'

const sampleStore = {
  id: 'store_abc123',
  name: 'Demo Store',
  url: 'demo.spreecommerce.org',
  default_currency: 'USD',
  created_at: '2026-05-01T00:00:00Z',
  updated_at: '2026-05-01T00:00:00Z',
}

describe('store', () => {
  describe('get', () => {
    it('GETs /store', async () => {
      server.use(http.get(`${API_PREFIX}/store`, () => HttpResponse.json(sampleStore)))

      const res = await createTestClient().store.get()

      expect(res.id).toBe('store_abc123')
    })
  })

  describe('update', () => {
    it('PATCHes /store with the params verbatim', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.patch(`${API_PREFIX}/store`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json({ ...sampleStore, name: 'Renamed Store' })
        }),
      )

      const res = await createTestClient().store.update({ name: 'Renamed Store' })

      expect(body).toEqual({ name: 'Renamed Store' })
      expect(res.name).toBe('Renamed Store')
    })
  })
})

describe('me', () => {
  describe('get', () => {
    it('GETs /me and returns the user + permissions', async () => {
      server.use(
        http.get(`${API_PREFIX}/me`, () =>
          HttpResponse.json({ user: { id: 'usr_1', email: 'a@b.c' }, permissions: [] }),
        ),
      )

      const res = await createTestClient().me.get()

      expect(res.user.id).toBe('usr_1')
      expect(res.permissions).toEqual([])
    })
  })
})

describe('dashboard', () => {
  describe('analytics', () => {
    it('GETs /dashboard/analytics', async () => {
      let hit = false
      server.use(
        http.get(`${API_PREFIX}/dashboard/analytics`, () => {
          hit = true
          return HttpResponse.json({ orders_count: 0, total_sales: '0.0' })
        }),
      )

      await createTestClient().dashboard.analytics()

      expect(hit).toBe(true)
    })

    it('forwards optional query params', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/dashboard/analytics`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json({ orders_count: 0, total_sales: '0.0' })
        }),
      )

      await createTestClient().dashboard.analytics({
        date_from: '2026-05-01',
        date_to: '2026-05-31',
        currency: 'EUR',
      })

      expect(url!.searchParams.get('date_from')).toBe('2026-05-01')
      expect(url!.searchParams.get('date_to')).toBe('2026-05-31')
      expect(url!.searchParams.get('currency')).toBe('EUR')
    })
  })
})

describe('directUploads', () => {
  describe('create', () => {
    it('POSTs /direct_uploads and returns the signed upload', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(`${API_PREFIX}/direct_uploads`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json(
            {
              direct_upload: {
                url: 'https://uploads.example.com/abc',
                headers: { 'Content-Type': 'image/png' },
              },
              signed_id: 'signed_xyz789',
            },
            { status: 201 },
          )
        }),
      )

      const res = await createTestClient().directUploads.create({
        blob: {
          filename: 'logo.png',
          byte_size: 1024,
          checksum: 'abc==',
          content_type: 'image/png',
        },
      })

      expect(body).toEqual({
        blob: {
          filename: 'logo.png',
          byte_size: 1024,
          checksum: 'abc==',
          content_type: 'image/png',
        },
      })
      expect(res.signed_id).toBe('signed_xyz789')
    })
  })
})
