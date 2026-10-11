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

describe('reporting', () => {
  describe('query', () => {
    it('POSTs the query body to /reporting/query', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(`${API_PREFIX}/reporting/query`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json({ meta: {}, totals: {}, rows: [] })
        }),
      )

      await createTestClient().reporting.query({
        metrics: ['gross_revenue'],
        dimensions: [{ name: 'completed_at', grain: 'day' }],
        compare: 'previous_period',
      })

      expect(body!.metrics).toEqual(['gross_revenue'])
      expect(body!.compare).toBe('previous_period')
    })
  })

  describe('schema', () => {
    it('GETs /reporting/schema', async () => {
      let hit = false
      server.use(
        http.get(`${API_PREFIX}/reporting/schema`, () => {
          hit = true
          return HttpResponse.json({ metrics: [], dimensions: [] })
        }),
      )

      await createTestClient().reporting.schema()

      expect(hit).toBe(true)
    })
  })
})

describe('dashboard', () => {
  describe('counters', () => {
    it('GETs /dashboard/counters and forwards the channel', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/dashboard/counters`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json({ channel_id: 'ch_1', counters: [] })
        }),
      )

      await createTestClient().dashboard.counters({ channel_id: 'ch_1' })

      expect(url!.searchParams.get('channel_id')).toBe('ch_1')
    })
  })
})

describe('files', () => {
  const fileUpload = {
    signed_id: 'signed_xyz789',
    filename: 'logo.png',
    content_type: 'image/png',
    byte_size: 4,
    visibility: 'public',
    expires_at: '2026-10-11T12:00:00Z',
  }

  describe('create', () => {
    it('POSTs flat metadata to /files', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(`${API_PREFIX}/files`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json({ ...fileUpload, upload: null }, { status: 201 })
        }),
      )

      const params = {
        filename: 'logo.png',
        byte_size: 4,
        checksum: 'abc==',
        content_type: 'image/png',
      }
      const res = await createTestClient().files.create(params)

      expect(body).toEqual(params)
      expect(res.signed_id).toBe('signed_xyz789')
    })
  })

  describe('upload', () => {
    it('reserves the file, sends its bytes to the storage target and returns the response', async () => {
      let created: Record<string, unknown> | null = null
      let stored: string | null = null
      server.use(
        http.post(`${API_PREFIX}/files`, async ({ request }) => {
          created = (await request.json()) as Record<string, unknown>
          return HttpResponse.json(
            {
              ...fileUpload,
              visibility: 'private',
              upload: {
                method: 'PUT',
                url: 'https://uploads.example.com/abc',
                headers: { 'Content-MD5': 'x' },
              },
            },
            { status: 201 },
          )
        }),
        http.put('https://uploads.example.com/abc', async ({ request }) => {
          stored = await request.text()
          return new HttpResponse(null, { status: 200 })
        }),
      )

      const file = new File(['logo'], 'logo.png', { type: 'image/png' })
      const res = await createTestClient().files.upload(file, { visibility: 'private' })

      expect(created).toMatchObject({
        filename: 'logo.png',
        content_type: 'image/png',
        byte_size: 4,
        checksum: 'ltby5+H3BateWchKbcAJsg==',
        visibility: 'private',
      })
      expect(stored).toBe('logo')
      expect(res.signed_id).toBe('signed_xyz789')
    })

    it('sends a multipart upload in the request itself', async () => {
      let file: FormDataEntryValue | null = null
      server.use(
        http.post(`${API_PREFIX}/files`, async ({ request }) => {
          file = (await request.formData()).get('file')
          return HttpResponse.json({ ...fileUpload, upload: null }, { status: 201 })
        }),
      )

      const res = await createTestClient().files.upload(
        new File(['logo'], 'logo.png', { type: 'image/png' }),
        {
          method: 'multipart',
        },
      )

      expect(file).toBeInstanceOf(File)
      expect(res.upload).toBeNull()
    })
  })
})
