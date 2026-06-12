import { HttpResponse, http } from 'msw'
import { describe, expect, it } from 'vitest'
import { API_PREFIX, createTestClient, createUnauthenticatedClient } from './helpers'
import { server } from './mocks/server'

// Guards the test-helper auth contract: the default client must authenticate
// server-to-server via `X-Spree-Api-Key`, and the unauthenticated client must
// not. Without these, a helper refactor could silently drop the secret key and
// every resource spec would still pass while no longer exercising admin auth.
describe('test helpers — auth contract', () => {
  it('createTestClient sends the secret key as X-Spree-Api-Key', async () => {
    let apiKeyHeader: string | null = null
    let authHeader: string | null = null
    server.use(
      http.get(`${API_PREFIX}/products`, ({ request }) => {
        apiKeyHeader = request.headers.get('X-Spree-Api-Key')
        authHeader = request.headers.get('Authorization')
        return HttpResponse.json({ data: [], meta: { page: 1, limit: 25, count: 0, pages: 0 } })
      }),
    )

    await createTestClient().products.list()

    expect(apiKeyHeader).toBe('sk_test')
    expect(authHeader).toBeNull()
  })

  it('createUnauthenticatedClient sends no auth credential', async () => {
    let apiKeyHeader: string | null = null
    let authHeader: string | null = null
    server.use(
      http.get(`${API_PREFIX}/products`, ({ request }) => {
        apiKeyHeader = request.headers.get('X-Spree-Api-Key')
        authHeader = request.headers.get('Authorization')
        return HttpResponse.json({ data: [], meta: { page: 1, limit: 25, count: 0, pages: 0 } })
      }),
    )

    await createUnauthenticatedClient().products.list()

    expect(apiKeyHeader).toBeNull()
    // No secret key and no JWT → no Bearer credential. The header is either
    // omitted or empty, but never carries a value.
    expect(authHeader ?? '').toBe('')
  })
})
