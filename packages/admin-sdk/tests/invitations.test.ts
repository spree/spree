import { HttpResponse, http } from 'msw'
import { describe, expect, it } from 'vitest'
import { API_PREFIX, createTestClient } from './helpers'
import { server } from './mocks/server'

const sampleInvitation = {
  id: 'inv_abc123',
  email: 'new-staff@example.com',
  status: 'pending',
  role_id: 'role_1',
  expires_at: '2026-06-01T00:00:00Z',
  created_at: '2026-05-01T00:00:00Z',
  updated_at: '2026-05-01T00:00:00Z',
}

describe('invitations', () => {
  describe('list / get', () => {
    it('GETs /invitations', async () => {
      server.use(
        http.get(`${API_PREFIX}/invitations`, () =>
          HttpResponse.json({
            data: [sampleInvitation],
            meta: { page: 1, limit: 25, count: 1, pages: 1 },
          }),
        ),
      )

      const res = await createTestClient().invitations.list()

      expect(res.data[0]?.id).toBe('inv_abc123')
    })
  })

  describe('create', () => {
    it('POSTs email + role_id', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(`${API_PREFIX}/invitations`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json(sampleInvitation, { status: 201 })
        }),
      )

      await createTestClient().invitations.create({
        email: 'new-staff@example.com',
        role_id: 'role_1',
      })

      expect(body).toEqual({ email: 'new-staff@example.com', role_id: 'role_1' })
    })
  })

  describe('resend', () => {
    it('PATCHes /invitations/:id/resend', async () => {
      let hit = false
      server.use(
        http.patch(`${API_PREFIX}/invitations/inv_abc123/resend`, () => {
          hit = true
          return HttpResponse.json(sampleInvitation)
        }),
      )

      await createTestClient().invitations.resend('inv_abc123')
      expect(hit).toBe(true)
    })
  })

  describe('delete', () => {
    it('DELETEs /invitations/:id', async () => {
      let hit = false
      server.use(
        http.delete(`${API_PREFIX}/invitations/inv_abc123`, () => {
          hit = true
          return new HttpResponse(null, { status: 204 })
        }),
      )

      await expect(createTestClient().invitations.delete('inv_abc123')).resolves.toBeUndefined()
      expect(hit).toBe(true)
    })
  })
})
