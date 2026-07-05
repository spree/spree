import { HttpResponse, http } from 'msw'
import { describe, expect, it } from 'vitest'
import { createTestClient, TEST_BASE_URL } from './helpers'
import { server } from './mocks/server'

const API_PREFIX = `${TEST_BASE_URL}/api/v3/store`

describe('auth', () => {
  describe('login', () => {
    it('returns auth tokens on successful login', async () => {
      const client = createTestClient()
      const result = await client.auth.login({
        email: 'test@example.com',
        password: 'password123',
      })

      expect(result.token).toBe('test-jwt-token')
      expect(result.user.email).toBe('test@example.com')
    })

    it('throws SpreeError on invalid credentials', async () => {
      server.use(
        http.post(`${API_PREFIX}/auth/login`, () =>
          HttpResponse.json(
            { error: { code: 'unauthorized', message: 'Invalid credentials' } },
            { status: 401 },
          ),
        ),
      )

      const client = createTestClient()
      await expect(
        client.auth.login({ email: 'bad@example.com', password: 'wrong' }),
      ).rejects.toThrow('Invalid credentials')
    })
  })

  describe('register (via customers.create)', () => {
    it('returns auth tokens on successful registration', async () => {
      const client = createTestClient()
      const result = await client.customers.create({
        email: 'new@example.com',
        password: 'password123',
        password_confirmation: 'password123',
        first_name: 'New',
        last_name: 'User',
      })

      expect(result.token).toBeDefined()
      expect(result.user).toBeDefined()
    })

    it('sends phone, accepts_email_marketing, and metadata', async () => {
      let capturedBody: Record<string, unknown> = {}
      server.use(
        http.post(`${API_PREFIX}/customers`, async ({ request }) => {
          capturedBody = (await request.json()) as Record<string, unknown>
          return HttpResponse.json({
            token: 'test-jwt-token',
            user: { id: 'user_1', email: 'new@example.com', first_name: null, last_name: null },
          })
        }),
      )

      const client = createTestClient()
      await client.customers.create({
        email: 'new@example.com',
        password: 'password123',
        password_confirmation: 'password123',
        phone: '+1234567890',
        accepts_email_marketing: true,
        metadata: { source: 'storefront' },
      })

      expect(capturedBody.phone).toBe('+1234567890')
      expect(capturedBody.accepts_email_marketing).toBe(true)
      expect(capturedBody.metadata).toEqual({ source: 'storefront' })
    })

    it('throws SpreeError on validation failure', async () => {
      server.use(
        http.post(`${API_PREFIX}/customers`, () =>
          HttpResponse.json(
            {
              error: {
                code: 'unprocessable_entity',
                message: 'Validation failed',
                details: { email: ['has already been taken'] },
              },
            },
            { status: 422 },
          ),
        ),
      )

      const client = createTestClient()
      try {
        await client.customers.create({
          email: 'existing@example.com',
          password: 'password123',
          password_confirmation: 'password123',
        })
        expect.unreachable('Should have thrown')
      } catch (error: any) {
        expect(error.code).toBe('unprocessable_entity')
        expect(error.status).toBe(422)
        expect(error.details?.email).toContain('has already been taken')
      }
    })
  })

  describe('refresh', () => {
    it('returns new access token and rotated refresh token', async () => {
      const client = createTestClient()
      const result = await client.auth.refresh({ refresh_token: 'rt_old' })

      expect(result.token).toBe('refreshed-jwt-token')
      expect(result.refresh_token).toBe('rt_refreshed')
    })
  })

  describe('logout', () => {
    it('revokes the refresh token', async () => {
      const client = createTestClient()
      await client.auth.logout({ refresh_token: 'rt_login' })
      // 204 No Content — no error means success
    })
  })
})
