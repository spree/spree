import type { RequestCompleteEvent } from '@spree/admin-sdk'
import { afterEach, describe, expect, it } from 'vitest'
import {
  clearDeveloperInspector,
  DEVELOPER_INSPECTOR_LIMIT,
  getDeveloperInspectorEntries,
  recordRequest,
  redactBody,
} from './developer-inspector'
import { entryToCurl, entryToSdkCall } from './request-snippets'

function event(overrides: Partial<RequestCompleteEvent> = {}): RequestCompleteEvent {
  return {
    method: 'GET',
    path: '/api/v3/admin/products',
    url: 'http://localhost/api/v3/admin/products',
    status: 200,
    durationMs: 12.4,
    requestId: 'req-1',
    requestHeaders: {
      'Content-Type': 'application/json',
      Authorization: 'Bearer real-jwt',
      'X-Spree-Store-Id': 'store_1',
      'Idempotency-Key': 'spree-sdk-retry-1',
    },
    requestBody: undefined,
    responseBody: { data: [] },
    ...overrides,
  }
}

afterEach(() => clearDeveloperInspector())

describe('recordRequest', () => {
  it('records newest first, with the token and secrets masked', () => {
    recordRequest(event())
    recordRequest(
      event({
        method: 'POST',
        path: '/api/v3/admin/auth/login',
        requestBody: { email: 'a@b.c', password: 'hunter2' },
        responseBody: { token: 'jwt', user: { api_keys: [{ Secret_Key: 'sk_1', name: 'k' }] } },
      }),
    )

    const [login, list] = getDeveloperInspectorEntries()
    expect(list.path).toBe('/api/v3/admin/products')
    expect(list.durationMs).toBe(12)
    expect(login.requestHeaders.Authorization).toBe('[FILTERED]')
    expect(login.requestBody).toEqual({ email: 'a@b.c', password: '[FILTERED]' })
    expect(login.responseBody).toEqual({
      token: '[FILTERED]',
      user: { api_keys: [{ Secret_Key: '[FILTERED]', name: 'k' }] },
    })
  })

  it('masks a password reset token carried in the path', () => {
    recordRequest(
      event({
        method: 'PATCH',
        path: '/api/v3/admin/auth/password_resets/reset-token-123',
        url: 'http://localhost/api/v3/admin/auth/password_resets/reset-token-123',
        status: 422,
      }),
    )

    const [reset] = getDeveloperInspectorEntries()
    expect(reset.path).toBe('/api/v3/admin/auth/password_resets/[FILTERED]')
    expect(reset.url).toBe('http://localhost/api/v3/admin/auth/password_resets/[FILTERED]')
    expect(JSON.stringify(reset)).not.toContain('reset-token-123')
  })

  it('masks secret query parameters in the query and the URL', () => {
    recordRequest(
      event({
        query: { page: 2, token: 'tok_1' },
        url: 'http://localhost/api/v3/admin/products?page=2&token=tok_1',
      }),
    )

    const [entry] = getDeveloperInspectorEntries()
    expect(entry.query).toEqual({ page: 2, token: '[FILTERED]' })
    expect(entry.url).toBe('http://localhost/api/v3/admin/products?page=2&token=%5BFILTERED%5D')
  })

  it('keeps the API error code of a failed request', () => {
    recordRequest(
      event({
        status: 404,
        error: Object.assign(new Error('Not found'), { code: 'record_not_found' }),
      }),
    )

    expect(getDeveloperInspectorEntries()[0]).toMatchObject({
      errorCode: 'record_not_found',
      errorMessage: 'Not found',
    })
  })

  it(`keeps only the last ${DEVELOPER_INSPECTOR_LIMIT} requests`, () => {
    for (let i = 0; i < DEVELOPER_INSPECTOR_LIMIT + 5; i++) recordRequest(event())
    expect(getDeveloperInspectorEntries()).toHaveLength(DEVELOPER_INSPECTOR_LIMIT)
  })

  it('forgets everything when cleared', () => {
    recordRequest(event())
    clearDeveloperInspector()
    expect(getDeveloperInspectorEntries()).toEqual([])
  })
})

describe('redactBody', () => {
  it('leaves scalars and unrelated fields alone', () => {
    expect(redactBody('x')).toBe('x')
    expect(redactBody([{ name: 'a', token_count: null }])).toEqual([
      { name: 'a', token_count: null },
    ])
  })

  it("hides what Rails' filter_parameters hides", () => {
    expect(
      redactBody({
        key: 'color',
        preferences: { api_key: 'sk_live_1', private_key: 'pk', webhook_secret: 'whsec' },
        source: { cvv: '123', number: '4242' },
      }),
    ).toEqual({
      key: 'color',
      preferences: {
        api_key: '[FILTERED]',
        private_key: '[FILTERED]',
        webhook_secret: '[FILTERED]',
      },
      source: { cvv: '[FILTERED]', number: '4242' },
    })
  })
})

describe('request snippets', () => {
  it('builds a curl command with a placeholder token and no idempotency key', () => {
    recordRequest(
      event({
        method: 'PATCH',
        path: '/api/v3/admin/products/prod_1',
        query: { expand: ['variants'] },
        url: 'http://localhost/api/v3/admin/products/prod_1?expand=variants',
        requestBody: { name: "Bob's shirt" },
      }),
    )
    const curl = entryToCurl(getDeveloperInspectorEntries()[0])

    expect(curl).toContain(
      "curl -X PATCH 'http://localhost/api/v3/admin/products/prod_1?expand=variants'",
    )
    expect(curl).toContain('Authorization: Bearer $SPREE_API_TOKEN')
    expect(curl).toContain("'X-Spree-Store-Id: store_1'")
    expect(curl).not.toContain('real-jwt')
    expect(curl).not.toContain('Idempotency-Key')
    expect(curl).toContain(`"Bob'\\''s shirt"`)
  })

  it('builds an SDK call relative to the Admin API', () => {
    recordRequest(event({ query: { page: 2 } }))

    expect(entryToSdkCall(getDeveloperInspectorEntries()[0])).toBe(
      'await adminClient.request("GET", "/products", {\n  "params": {\n    "page": 2\n  }\n})',
    )
  })
})
