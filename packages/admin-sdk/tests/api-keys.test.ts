import { HttpResponse, http } from 'msw'
import { describe, expect, it } from 'vitest'
import { API_PREFIX, createTestClient } from './helpers'
import { server } from './mocks/server'

const sampleKey = {
  id: 'key_abc123',
  name: 'CI integration',
  key_type: 'secret',
  token_prefix: 'sk_abc123def',
  plaintext_token: null,
  scopes: ['read_orders', 'write_orders'],
  revoked_at: null,
  created_at: '2026-05-01T00:00:00Z',
  updated_at: '2026-05-01T00:00:00Z',
}

describe('apiKeys', () => {
  describe('list', () => {
    it('GETs /api_keys', async () => {
      server.use(
        http.get(`${API_PREFIX}/api_keys`, () =>
          HttpResponse.json({
            data: [sampleKey],
            meta: { page: 1, limit: 25, count: 1, pages: 1 },
          }),
        ),
      )

      const res = await createTestClient().apiKeys.list()

      expect(res.data[0]?.id).toBe('key_abc123')
    })
  })

  describe('create', () => {
    it('POSTs name + key_type + scopes and surfaces the one-time plaintext_token', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(`${API_PREFIX}/api_keys`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json(
            { ...sampleKey, plaintext_token: 'sk_abc123def456ghi789' },
            { status: 201 },
          )
        }),
      )

      const res = await createTestClient().apiKeys.create({
        name: 'CI integration',
        key_type: 'secret',
        scopes: ['read_orders', 'write_orders'],
      })

      expect(body).toEqual({
        name: 'CI integration',
        key_type: 'secret',
        scopes: ['read_orders', 'write_orders'],
      })
      // plaintext_token is returned exactly once on create.
      expect(res.plaintext_token).toBe('sk_abc123def456ghi789')
    })
  })

  describe('revoke', () => {
    it('PATCHes /api_keys/:id/revoke', async () => {
      let hit = false
      server.use(
        http.patch(`${API_PREFIX}/api_keys/key_abc123/revoke`, () => {
          hit = true
          return HttpResponse.json({ ...sampleKey, revoked_at: '2026-06-01T00:00:00Z' })
        }),
      )

      const res = await createTestClient().apiKeys.revoke('key_abc123')

      expect(hit).toBe(true)
      expect(res.revoked_at).toBe('2026-06-01T00:00:00Z')
    })
  })

  describe('delete', () => {
    it('DELETEs /api_keys/:id', async () => {
      let hit = false
      server.use(
        http.delete(`${API_PREFIX}/api_keys/key_abc123`, () => {
          hit = true
          return new HttpResponse(null, { status: 204 })
        }),
      )

      await expect(createTestClient().apiKeys.delete('key_abc123')).resolves.toBeUndefined()
      expect(hit).toBe(true)
    })
  })
})
