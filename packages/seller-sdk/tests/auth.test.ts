import { HttpResponse, http } from 'msw'
import { describe, expect, it, vi } from 'vitest'
import { createSellerClient, SpreeError } from '../src'
import { server } from './mocks/server'

const BASE_URL = 'http://api.test'
const API_PREFIX = `${BASE_URL}/api/v3/seller`

describe('non-JSON unauthorized responses', () => {
  it('refreshes the token before replaying the request once', async () => {
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
    const client = createSellerClient({
      baseUrl: BASE_URL,
      jwtToken: 'expired-token',
      retry: { baseDelay: 0 },
    })
    const onUnauthorized = vi.fn(async () => {
      client.setToken('refreshed-token')
      return true
    })
    client.onUnauthorized(onUnauthorized)

    await expect(client.products.list()).resolves.toEqual({ data: [] })
    expect(onUnauthorized).toHaveBeenCalledTimes(1)
    expect(tokens).toEqual(['Bearer expired-token', 'Bearer refreshed-token'])
  })

  it('preserves the HTTP error when session recovery is declined', async () => {
    const handleProducts = vi.fn(() =>
      HttpResponse.html('<html>Unauthorized</html>', { status: 401 }),
    )
    server.use(http.get(`${API_PREFIX}/products`, handleProducts))
    const client = createSellerClient({ baseUrl: BASE_URL, retry: { baseDelay: 0 } })
    const onUnauthorized = vi.fn(async () => false)
    client.onUnauthorized(onUnauthorized)

    const request = client.products.list()

    await expect(request).rejects.toBeInstanceOf(SpreeError)
    await expect(request).rejects.toMatchObject({ status: 401 })
    expect(handleProducts).toHaveBeenCalledTimes(1)
    expect(onUnauthorized).toHaveBeenCalledTimes(1)
  })

  it('stops after the replay also returns an unauthorized response', async () => {
    const tokens: string[] = []
    server.use(
      http.get(`${API_PREFIX}/products`, ({ request }) => {
        tokens.push(request.headers.get('Authorization') ?? '')
        return HttpResponse.html('<html>Unauthorized</html>', { status: 401 })
      }),
    )
    const client = createSellerClient({
      baseUrl: BASE_URL,
      jwtToken: 'expired-token',
      retry: { baseDelay: 0 },
    })
    const onUnauthorized = vi.fn(async () => {
      client.setToken('refreshed-token')
      return true
    })
    client.onUnauthorized(onUnauthorized)

    const request = client.products.list()

    await expect(request).rejects.toBeInstanceOf(SpreeError)
    await expect(request).rejects.toMatchObject({ status: 401 })
    expect(tokens).toEqual(['Bearer expired-token', 'Bearer refreshed-token'])
    expect(onUnauthorized).toHaveBeenCalledTimes(1)
  })

  it('does not invoke session recovery for a failed login', async () => {
    const handleLogin = vi.fn(() => HttpResponse.html('<html>Unauthorized</html>', { status: 401 }))
    server.use(http.post(`${API_PREFIX}/auth/login`, handleLogin))
    const client = createSellerClient({ baseUrl: BASE_URL, retry: { baseDelay: 0 } })
    const onUnauthorized = vi.fn(async () => true)
    client.onUnauthorized(onUnauthorized)

    const request = client.auth.login({ email: 'seller@example.com', password: 'password' })

    await expect(request).rejects.toBeInstanceOf(SpreeError)
    await expect(request).rejects.toMatchObject({ status: 401 })
    expect(handleLogin).toHaveBeenCalledTimes(1)
    expect(onUnauthorized).not.toHaveBeenCalled()
  })
})
