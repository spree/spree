import { HttpResponse, http } from 'msw'
import { describe, expect, it } from 'vitest'
import { API_PREFIX, createTestClient } from './helpers'
import { server } from './mocks/server'

const sampleAdminUser = {
  id: 'usr_abc123',
  email: 'staff@example.com',
  first_name: 'Sam',
  last_name: 'Staff',
  created_at: '2026-05-01T00:00:00Z',
  updated_at: '2026-05-01T00:00:00Z',
}

describe('adminUsers', () => {
  describe('list', () => {
    it('GETs /admin_users', async () => {
      server.use(
        http.get(`${API_PREFIX}/admin_users`, () =>
          HttpResponse.json({
            data: [sampleAdminUser],
            meta: { page: 1, limit: 25, count: 1, pages: 1 },
          }),
        ),
      )

      const res = await createTestClient().adminUsers.list()

      expect(res.data[0]?.id).toBe('usr_abc123')
    })
  })

  describe('update', () => {
    it('PATCHes identity fields + role_ids', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.patch(`${API_PREFIX}/admin_users/usr_abc123`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json(sampleAdminUser)
        }),
      )

      await createTestClient().adminUsers.update('usr_abc123', {
        first_name: 'Sam',
        role_ids: ['role_1', 'role_2'],
      })

      expect(body).toEqual({ first_name: 'Sam', role_ids: ['role_1', 'role_2'] })
    })
  })

  describe('delete', () => {
    it('DELETEs /admin_users/:id (removes store role assignments)', async () => {
      let hit = false
      server.use(
        http.delete(`${API_PREFIX}/admin_users/usr_abc123`, () => {
          hit = true
          return new HttpResponse(null, { status: 204 })
        }),
      )

      await expect(createTestClient().adminUsers.delete('usr_abc123')).resolves.toBeUndefined()
      expect(hit).toBe(true)
    })
  })
})
