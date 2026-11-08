import { HttpResponse, http } from 'msw'
import { describe, expect, it } from 'vitest'
import { createTestClient, TEST_BASE_URL } from './helpers'
import { server } from './mocks/server'

const API_PREFIX = `${TEST_BASE_URL}/api/v3/store`

const dataRequest = {
  id: 'dsr_UkLWZg9DAJ',
  number: 'DSR1001',
  kind: 'access',
  status: 'awaiting_confirmation',
  requested_at: '2026-10-19T10:00:00Z',
  completed_at: null,
  expires_at: null,
  download_url: null,
}

describe('customer.dataRequests', () => {
  it('opens a request with the page the confirmation link opens', async () => {
    let capturedBody: Record<string, unknown> = {}
    server.use(
      http.post(`${API_PREFIX}/customers/me/data_requests`, async ({ request }) => {
        capturedBody = (await request.json()) as Record<string, unknown>
        return HttpResponse.json(dataRequest, { status: 202 })
      }),
    )

    const client = createTestClient()
    const result = await client.customer.dataRequests.create(
      { kind: 'access', redirect_url: 'https://myshop.com/account/data-requests/confirm' },
      { token: 'customer-jwt' },
    )

    expect(result.status).toBe('awaiting_confirmation')
    expect(capturedBody).toEqual({
      kind: 'access',
      redirect_url: 'https://myshop.com/account/data-requests/confirm',
    })
  })

  it('lists the customer requests', async () => {
    server.use(
      http.get(`${API_PREFIX}/customers/me/data_requests`, () =>
        HttpResponse.json({
          data: [dataRequest],
          meta: { page: 1, limit: 25, count: 1, pages: 1 },
        }),
      ),
    )

    const client = createTestClient()
    const result = await client.customer.dataRequests.list({}, { token: 'customer-jwt' })

    expect(result.data[0].id).toBe('dsr_UkLWZg9DAJ')
  })
})

describe('dataRequests', () => {
  it('confirms a request with the emailed token', async () => {
    let calledPath = ''
    server.use(
      http.post(`${API_PREFIX}/data_requests/:token/confirmation`, ({ params }) => {
        calledPath = String(params.token)
        return HttpResponse.json({ ...dataRequest, status: 'pending' })
      }),
    )

    const client = createTestClient()
    const result = await client.dataRequests.confirm('signed--token')

    expect(calledPath).toBe('signed--token')
    expect(result.status).toBe('pending')
  })

  it('reads the request, with its download link, by the emailed token', async () => {
    server.use(
      http.get(`${API_PREFIX}/data_requests/:token`, () =>
        HttpResponse.json({
          ...dataRequest,
          status: 'completed',
          download_url: 'https://api.myshop.com/api/v3/store/data_requests/abc/download',
        }),
      ),
    )

    const client = createTestClient()
    const result = await client.dataRequests.get('signed--token')

    expect(result.download_url).toContain('/download')
  })
})
