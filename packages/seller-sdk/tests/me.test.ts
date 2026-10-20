import { HttpResponse, http } from 'msw'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { createSellerClient } from '../src'
import { server } from './mocks/server'

const BASE_URL = 'http://api.test'
const API_PREFIX = `${BASE_URL}/api/v3/seller`

const meResponse = {
  user: {
    id: 'admin_1',
    email: 'seller@example.com',
    first_name: 'Ada',
    last_name: 'Lovelace',
    full_name: 'Ada Lovelace',
    created_at: '2026-09-01T00:00:00Z',
    avatar_url: null,
    selected_locale: 'de',
  },
  sellers: [],
  permissions: [],
  permission_keys: [],
}

function buildClient() {
  return createSellerClient({ baseUrl: BASE_URL, jwtToken: 'token', retry: false })
}

describe('client.me', () => {
  afterEach(() => {
    vi.restoreAllMocks()
  })

  it('reads the signed-in person with me.get()', async () => {
    server.use(http.get(`${API_PREFIX}/me`, () => HttpResponse.json(meResponse)))
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => {})

    await expect(buildClient().me.get()).resolves.toEqual(meResponse)
    expect(warn).not.toHaveBeenCalled()
  })

  it('updates the signed-in person with me.update()', async () => {
    let body: unknown
    server.use(
      http.patch(`${API_PREFIX}/me`, async ({ request }) => {
        body = await request.json()
        return HttpResponse.json({
          ...meResponse,
          user: { ...meResponse.user, first_name: 'Grace' },
        })
      }),
    )

    const result = await buildClient().me.update({ first_name: 'Grace', avatar: null })

    expect(body).toEqual({ first_name: 'Grace', avatar: null })
    expect(result.user.first_name).toBe('Grace')
  })

  it('still answers the deprecated me() call, warning once per client', async () => {
    const handler = vi.fn(() => HttpResponse.json(meResponse))
    server.use(http.get(`${API_PREFIX}/me`, handler))
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => {})
    const client = buildClient()

    await expect(client.me()).resolves.toEqual(meResponse)
    await expect(client.me()).resolves.toEqual(meResponse)

    expect(handler).toHaveBeenCalledTimes(2)
    expect(warn).toHaveBeenCalledTimes(1)
    expect(warn.mock.calls[0]?.[0]).toContain('client.me.get()')
  })
})
