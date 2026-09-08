import { HttpResponse, http } from 'msw'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { createAdminClient, SpreeError } from '../src'
import { API_PREFIX, BASE_URL, createUnauthenticatedClient } from './helpers'
import { server } from './mocks/server'

describe('auth', () => {
  describe('non-JSON unauthorized responses', () => {
    it('refreshes the token before retrying the original request', async () => {
      const tokens: string[] = []
      server.use(
        http.get(`${API_PREFIX}/products`, ({ request }) => {
          tokens.push(request.headers.get('Authorization') ?? '')
          if (tokens.length === 1) {
            return HttpResponse.html('<html>Unauthorized</html>', { status: 401 })
          }
          return HttpResponse.json({ data: [] })
        }),
      )
      const client = createAdminClient({ baseUrl: BASE_URL, jwtToken: 'expired-token' })
      const onUnauthorized = vi.fn(async () => {
        client.setToken('refreshed-token')
        return true
      })
      client.onUnauthorized(onUnauthorized)

      await expect(client.products.list()).resolves.toEqual({ data: [] })
      expect(onUnauthorized).toHaveBeenCalledTimes(1)
      expect(tokens).toEqual(['Bearer expired-token', 'Bearer refreshed-token'])
    })

    it('does not invoke session recovery for a failed login', async () => {
      const handleLogin = vi.fn(() => new HttpResponse(null, { status: 401 }))
      server.use(http.post(`${API_PREFIX}/auth/login`, handleLogin))
      const client = createUnauthenticatedClient()
      const onUnauthorized = vi.fn(async () => true)
      client.onUnauthorized(onUnauthorized)

      await expect(client.auth.login({ email: 'a@b.c', password: 'p' })).rejects.toBeInstanceOf(
        SpreeError,
      )
      expect(handleLogin).toHaveBeenCalledTimes(1)
      expect(onUnauthorized).not.toHaveBeenCalled()
    })
  })

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
      const client = createUnauthenticatedClient()
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

      const client = createUnauthenticatedClient()
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

      const client = createUnauthenticatedClient()
      await expect(client.auth.logout()).resolves.toBeUndefined()
      expect(hit).toBe(true)
    })
  })
})
