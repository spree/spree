import { HttpResponse, http } from 'msw'
import { beforeEach, describe, expect, it } from 'vitest'
import { createAdminClient } from '../src'
import { server } from './mocks/server'

const BASE_URL = 'https://demo.spreecommerce.org'
const API_PREFIX = `${BASE_URL}/api/v3/admin`

describe('auth', () => {
  describe('login', () => {
    beforeEach(() => {
      server.use(
        http.post(`${API_PREFIX}/auth/login`, async ({ request }) => {
          const body = (await request.json()) as { email: string; password: string }
          return HttpResponse.json({
            token: 'jwt_access_token',
            user: { id: 'usr_1', email: body.email, first_name: 'A', last_name: 'B' },
          })
        }),
      )
    })

    it('returns { token, user } and does not include refresh_token in body', async () => {
      const client = createAdminClient({ baseUrl: BASE_URL })
      const res = await client.auth.login({ email: 'a@b.c', password: 'p' })
      expect(res.token).toBe('jwt_access_token')
      expect(res.user.email).toBe('a@b.c')
      expect((res as Record<string, unknown>).refresh_token).toBeUndefined()
    })
  })

  describe('refresh', () => {
    it('POSTs to /auth/refresh with no body — refresh cookie carries the credential', async () => {
      let observedBody: string | null = null
      server.use(
        http.post(`${API_PREFIX}/auth/refresh`, async ({ request }) => {
          observedBody = await request.text()
          return HttpResponse.json({
            token: 'new_jwt',
            user: { id: 'usr_1', email: 'a@b.c', first_name: null, last_name: null },
          })
        }),
      )

      const client = createAdminClient({ baseUrl: BASE_URL })
      const res = await client.auth.refresh()

      expect(observedBody).toBe('') // no body sent — credential is the cookie
      expect(res.token).toBe('new_jwt')
    })
  })

  describe('logout', () => {
    it('POSTs to /auth/logout and resolves to undefined', async () => {
      let hit = false
      server.use(
        http.post(`${API_PREFIX}/auth/logout`, () => {
          hit = true
          return new HttpResponse(null, { status: 204 })
        }),
      )

      const client = createAdminClient({ baseUrl: BASE_URL })
      await expect(client.auth.logout()).resolves.toBeUndefined()
      expect(hit).toBe(true)
    })
  })
})
