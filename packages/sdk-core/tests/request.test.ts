import { describe, expect, it, vi } from 'vitest'
import { createRequestFn, type RequestCompleteEvent, SpreeError } from '../src/request'

function jsonResponse(body: unknown, status = 200, headers: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...headers },
  })
}

function buildRequest(
  fetchFn: typeof fetch,
  onRequestComplete?: (event: RequestCompleteEvent) => void,
  retry = false,
) {
  return createRequestFn(
    {
      baseUrl: 'https://api.test.com',
      fetchFn,
      retryConfig: retry
        ? {
            maxRetries: 1,
            retryOnStatus: [500],
            baseDelay: 0,
            maxDelay: 0,
            retryOnNetworkError: true,
          }
        : false,
      onRequestComplete,
    },
    '/api/v3/admin',
    { headerName: 'Authorization', headerValue: 'Bearer secret-jwt' },
  )
}

describe('onRequestComplete', () => {
  it('reports a successful request with its request ID and bodies', async () => {
    const responseBody = { id: 'prod_1', name: 'Shirt' }
    const fetchFn = vi
      .fn()
      .mockResolvedValue(jsonResponse(responseBody, 200, { 'X-Request-Id': 'req-123' }))
    const onRequestComplete = vi.fn()
    const requestBody = { name: 'Shirt' }

    const result = await buildRequest(fetchFn, onRequestComplete)('PATCH', '/products/prod_1', {
      body: requestBody,
      params: { expand: 'variants' },
    })

    expect(result).toEqual(responseBody)
    expect(onRequestComplete).toHaveBeenCalledTimes(1)
    const event: RequestCompleteEvent = onRequestComplete.mock.calls[0][0]
    expect(event).toMatchObject({
      method: 'PATCH',
      path: '/api/v3/admin/products/prod_1',
      query: { expand: 'variants' },
      status: 200,
      requestId: 'req-123',
      responseBody,
    })
    expect(event.url).toMatch(/\/api\/v3\/admin\/products\/prod_1\?expand=variants$/)
    expect(event.requestBody).toBe(requestBody)
    expect(event.requestHeaders.Authorization).toBe('Bearer secret-jwt')
    expect(event.durationMs).toBeGreaterThanOrEqual(0)
    expect(event).not.toHaveProperty('error')
  })

  it('reports an API error with the parsed body and the thrown error', async () => {
    const errorBody = { error: { code: 'record_not_found', message: 'Not found' } }
    const fetchFn = vi
      .fn()
      .mockResolvedValue(jsonResponse(errorBody, 404, { 'X-Request-Id': 'req-404' }))
    const onRequestComplete = vi.fn()

    await expect(buildRequest(fetchFn, onRequestComplete)('GET', '/products/nope')).rejects.toThrow(
      SpreeError,
    )

    const event: RequestCompleteEvent = onRequestComplete.mock.calls[0][0]
    expect(event).toMatchObject({ status: 404, requestId: 'req-404', responseBody: errorBody })
    expect(event.error).toBeInstanceOf(SpreeError)
    expect((event.error as SpreeError).code).toBe('record_not_found')
  })

  it('reports a network failure with a null status', async () => {
    const fetchFn = vi.fn().mockRejectedValue(new TypeError('Failed to fetch'))
    const onRequestComplete = vi.fn()

    await expect(buildRequest(fetchFn, onRequestComplete)('GET', '/products')).rejects.toThrow(
      'Failed to fetch',
    )

    expect(onRequestComplete.mock.calls[0][0]).toMatchObject({
      status: null,
      requestId: null,
      error: expect.any(TypeError),
    })
  })

  it('reports every attempt of a retried request', async () => {
    const fetchFn = vi
      .fn()
      .mockResolvedValueOnce(jsonResponse({ error: { code: 'x', message: 'x' } }, 500))
      .mockResolvedValueOnce(jsonResponse({ data: [] }))
    const onRequestComplete = vi.fn()

    await buildRequest(fetchFn, onRequestComplete, true)('GET', '/products')

    expect(onRequestComplete.mock.calls.map(([event]) => event.status)).toEqual([500, 200])
  })

  it('reports a 204 with no response body', async () => {
    const fetchFn = vi.fn().mockResolvedValue(new Response(null, { status: 204 }))
    const onRequestComplete = vi.fn()

    await buildRequest(fetchFn, onRequestComplete)('DELETE', '/products/prod_1')

    expect(onRequestComplete.mock.calls[0][0]).toMatchObject({
      status: 204,
      responseBody: undefined,
    })
  })

  it('still resolves when the listener throws', async () => {
    const fetchFn = vi.fn().mockResolvedValue(jsonResponse({ ok: true }))
    const onRequestComplete = vi.fn(() => {
      throw new Error('listener bug')
    })

    await expect(buildRequest(fetchFn, onRequestComplete)('GET', '/products')).resolves.toEqual({
      ok: true,
    })
  })

  it('works unchanged without a listener', async () => {
    const fetchFn = vi.fn().mockResolvedValue(jsonResponse({ ok: true }))

    await expect(buildRequest(fetchFn)('GET', '/products')).resolves.toEqual({ ok: true })
  })
})
