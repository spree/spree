import { HttpResponse, http } from 'msw'
import { beforeAll, describe, expect, it } from 'vitest'
import type { Client } from '../src'
import { createTestClient, TEST_BASE_URL } from './helpers'
import { fixtures } from './mocks/handlers'
import { server } from './mocks/server'

const API_PREFIX = `${TEST_BASE_URL}/api/v3/store`

describe('newsletterSubscribers', () => {
  let client: Client
  beforeAll(() => {
    client = createTestClient()
  })

  describe('create', () => {
    it('subscribes a guest email', async () => {
      const result = await client.newsletterSubscribers.create({
        email: 'subscriber@example.com',
      })

      expect(result.id).toBe('sub_1')
      expect(result.email).toBe('subscriber@example.com')
      expect(result.verified).toBe(false)
      expect(result.customer_id).toBeNull()
    })

    it('sends the email in the request body', async () => {
      let capturedBody: Record<string, unknown> = {}
      server.use(
        http.post(`${API_PREFIX}/newsletter_subscribers`, async ({ request }) => {
          capturedBody = (await request.json()) as Record<string, unknown>
          return HttpResponse.json(fixtures.newsletterSubscriber, { status: 201 })
        }),
      )

      await client.newsletterSubscribers.create({ email: 'guest@example.com' })

      expect(capturedBody.email).toBe('guest@example.com')
    })

    it('forwards redirect_url for webhook-driven confirmation emails', async () => {
      let capturedBody: Record<string, unknown> = {}
      server.use(
        http.post(`${API_PREFIX}/newsletter_subscribers`, async ({ request }) => {
          capturedBody = (await request.json()) as Record<string, unknown>
          return HttpResponse.json(fixtures.newsletterSubscriber, { status: 201 })
        }),
      )

      await client.newsletterSubscribers.create({
        email: 'guest@example.com',
        redirect_url: 'https://storefront.example.com/newsletter/confirm',
      })

      expect(capturedBody.redirect_url).toBe('https://storefront.example.com/newsletter/confirm')
    })

    it('forwards a JWT when provided', async () => {
      let capturedAuth: string | null = null
      server.use(
        http.post(`${API_PREFIX}/newsletter_subscribers`, ({ request }) => {
          capturedAuth = request.headers.get('Authorization')
          return HttpResponse.json(
            {
              ...fixtures.newsletterSubscriber,
              verified: true,
              verified_at: '2026-01-02T00:00:00Z',
              customer_id: 'user_1',
            },
            { status: 201 },
          )
        }),
      )

      const result = await client.newsletterSubscribers.create(
        { email: 'test@example.com' },
        { token: 'user-jwt' },
      )

      expect(capturedAuth).toBe('Bearer user-jwt')
      expect(result.verified).toBe(true)
      expect(result.customer_id).toBe('user_1')
    })
  })

  describe('verify', () => {
    it('verifies a subscription using the token', async () => {
      const result = await client.newsletterSubscribers.verify({ token: 'abc123' })

      expect(result.verified).toBe(true)
      expect(result.verified_at).toBe('2026-01-02T00:00:00Z')
    })

    it('sends the token in the request body', async () => {
      let capturedBody: Record<string, unknown> = {}
      server.use(
        http.post(`${API_PREFIX}/newsletter_subscribers/verify`, async ({ request }) => {
          capturedBody = (await request.json()) as Record<string, unknown>
          return HttpResponse.json({
            ...fixtures.newsletterSubscriber,
            verified: true,
            verified_at: '2026-01-02T00:00:00Z',
          })
        }),
      )

      await client.newsletterSubscribers.verify({ token: 'verify-token-xyz' })

      expect(capturedBody.token).toBe('verify-token-xyz')
    })
  })

  describe('requestUnsubscribe', () => {
    it('resolves on the always-202 response', async () => {
      await expect(
        client.newsletterSubscribers.requestUnsubscribe({ email: 'subscriber@example.com' }),
      ).resolves.toBeUndefined()
    })

    it('sends the email and redirect_url in the request body', async () => {
      let capturedBody: Record<string, unknown> = {}
      server.use(
        http.post(
          `${API_PREFIX}/newsletter_subscribers/request_unsubscribe`,
          async ({ request }) => {
            capturedBody = (await request.json()) as Record<string, unknown>
            return new HttpResponse(null, { status: 202 })
          },
        ),
      )

      await client.newsletterSubscribers.requestUnsubscribe({
        email: 'subscriber@example.com',
        redirect_url: 'https://storefront.example.com/newsletter/unsubscribed',
      })

      expect(capturedBody.email).toBe('subscriber@example.com')
      expect(capturedBody.redirect_url).toBe(
        'https://storefront.example.com/newsletter/unsubscribed',
      )
    })
  })

  describe('delete', () => {
    it('unsubscribes with an unsubscribe token as a query param', async () => {
      let capturedUrl: URL | null = null
      server.use(
        http.delete(`${API_PREFIX}/newsletter_subscribers/:id`, ({ request }) => {
          capturedUrl = new URL(request.url)
          return new HttpResponse(null, { status: 204 })
        }),
      )

      await client.newsletterSubscribers.delete('sub_1', { token: 'unsubscribe-token-xyz' })

      expect(capturedUrl?.pathname).toBe('/api/v3/store/newsletter_subscribers/sub_1')
      expect(capturedUrl?.searchParams.get('token')).toBe('unsubscribe-token-xyz')
    })

    it('unsubscribes an authenticated customer via JWT without a token param', async () => {
      let capturedAuth: string | null = null
      let capturedUrl: URL | null = null
      server.use(
        http.delete(`${API_PREFIX}/newsletter_subscribers/:id`, ({ request }) => {
          capturedAuth = request.headers.get('Authorization')
          capturedUrl = new URL(request.url)
          return new HttpResponse(null, { status: 204 })
        }),
      )

      await client.newsletterSubscribers.delete('sub_1', undefined, { token: 'user-jwt' })

      expect(capturedAuth).toBe('Bearer user-jwt')
      expect(capturedUrl?.searchParams.has('token')).toBe(false)
    })
  })
})
