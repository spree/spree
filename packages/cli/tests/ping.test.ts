import { afterEach, describe, expect, it, vi } from 'vitest'
import {
  fetchCurrentKeyScopes,
  formatPingStatus,
  isPingFailure,
  type PingResult,
} from '../src/api/ping'

// biome-ignore lint/suspicious/noControlCharactersInRegex: matching ANSI SGR escapes
const stripAnsi = (s: string) => s.replace(/\x1b\[[0-9;]*m/g, '')

describe('isPingFailure', () => {
  it('treats a rejected key and an unreachable host as failures', () => {
    expect(isPingFailure({ status: 'unauthorized' })).toBe(true)
    expect(isPingFailure({ status: 'unreachable', message: 'ECONNREFUSED' })).toBe(true)
  })

  it('does NOT treat connected or forbidden as failures', () => {
    // `forbidden` = valid key that just lacks read_settings — still a healthy credential.
    expect(isPingFailure({ status: 'connected', storeName: 'Shop' })).toBe(false)
    expect(isPingFailure({ status: 'forbidden' })).toBe(false)
  })
})

describe('formatPingStatus', () => {
  const cases: Array<[PingResult, string]> = [
    [{ status: 'connected', storeName: 'Shop' }, 'connected (Shop)'],
    [{ status: 'forbidden' }, 'connected (key valid; lacks read_settings for store details)'],
    [{ status: 'unauthorized' }, 'key rejected (401)'],
    [{ status: 'unreachable', message: 'ECONNREFUSED' }, 'unreachable — ECONNREFUSED'],
  ]

  it.each(cases)('renders %j', (ping, expected) => {
    expect(stripAnsi(formatPingStatus(ping))).toBe(expected)
  })
})

describe('fetchCurrentKeyScopes', () => {
  afterEach(() => {
    vi.unstubAllGlobals()
  })

  function stubFetch(status: number, body: unknown) {
    vi.stubGlobal(
      'fetch',
      vi.fn(
        async () =>
          new Response(JSON.stringify(body), {
            status,
            headers: { 'content-type': 'application/json' },
          }),
      ),
    )
  }

  it('returns the live scopes from GET /api_keys/current', async () => {
    stubFetch(200, { scopes: ['read_orders', 'write_products'] })

    const scopes = await fetchCurrentKeyScopes('http://localhost:3000', 'sk_test')
    expect(scopes).toEqual(['read_orders', 'write_products'])
  })

  it('returns null when the server cannot report scopes (e.g. older server 404s)', async () => {
    stubFetch(404, { error: { message: 'not found' } })

    const scopes = await fetchCurrentKeyScopes('http://localhost:3000', 'sk_test')
    expect(scopes).toBeNull()
  })

  it('returns null on a transport failure', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => {
        throw new Error('ECONNREFUSED')
      }),
    )

    const scopes = await fetchCurrentKeyScopes('http://localhost:3000', 'sk_test')
    expect(scopes).toBeNull()
  })
})
