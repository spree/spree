import { HttpResponse, http } from 'msw'
import { describe, expect, it } from 'vitest'
import { createTestClient, TEST_BASE_URL } from './helpers'
import { server } from './mocks/server'

const API_PREFIX = `${TEST_BASE_URL}/api/v3/store`

describe('passwordResets', () => {
  describe('create (request password reset)', () => {
    it('returns a message on success', async () => {
      const client = createTestClient()
      const result = await client.passwordResets.create({
        email: 'test@example.com',
      })

      expect(result.message).toBeDefined()
    })

    it('sends email in request body', async () => {
      let capturedBody: Record<string, unknown> = {}
      server.use(
        http.post(`${API_PREFIX}/password_resets`, async ({ request }) => {
          capturedBody = (await request.json()) as Record<string, unknown>
          return HttpResponse.json(
            {
              message:
                'If an account exists for that email, password reset instructions have been sent.',
            },
            { status: 202 },
          )
        }),
      )

      const client = createTestClient()
      await client.passwordResets.create({ email: 'test@example.com' })

      expect(capturedBody.email).toBe('test@example.com')
    })
  })

  describe('update (reset password with token)', () => {
    it('returns auth tokens on successful reset', async () => {
      const client = createTestClient()
      const result = await client.passwordResets.update('valid-reset-token', {
        password: 'newsecurepassword',
        password_confirmation: 'newsecurepassword',
      })

      expect(result.token).toBe('new-jwt-token')
      expect(result.user.email).toBe('test@example.com')
    })

    it('sends token in URL path', async () => {
      let capturedUrl = ''
      server.use(
        http.patch(`${API_PREFIX}/password_resets/:token`, ({ request }) => {
          capturedUrl = request.url
          return HttpResponse.json({
            token: 'new-jwt-token',
            user: { id: 'user_1', email: 'test@example.com', first_name: null, last_name: null },
          })
        }),
      )

      const client = createTestClient()
      await client.passwordResets.update('my-reset-token', {
        password: 'newsecurepassword',
        password_confirmation: 'newsecurepassword',
      })

      expect(capturedUrl).toContain('/password_resets/my-reset-token')
    })

    it('throws SpreeError on invalid token', async () => {
      server.use(
        http.patch(`${API_PREFIX}/password_resets/:token`, () =>
          HttpResponse.json(
            {
              error: {
                code: 'password_reset_token_invalid',
                message: 'Password reset token is invalid or has expired.',
              },
            },
            { status: 422 },
          ),
        ),
      )

      const client = createTestClient()
      try {
        await client.passwordResets.update('expired-token', {
          password: 'newsecurepassword',
          password_confirmation: 'newsecurepassword',
        })
        expect.unreachable('Should have thrown')
      } catch (error: any) {
        expect(error.code).toBe('password_reset_token_invalid')
        expect(error.status).toBe(422)
      }
    })
  })
})
