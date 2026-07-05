import { HttpResponse, http } from 'msw'
import { describe, expect, it } from 'vitest'
import { API_PREFIX, createTestClient, paginated } from './helpers'
import { server } from './mocks/server'

const sampleEndpoint = {
  id: 'whe_abc123',
  name: 'Production',
  url: 'https://example.com/hooks',
  active: true,
  subscriptions: ['order.completed'],
  disabled_reason: null,
  created_at: '2026-05-01T00:00:00Z',
  updated_at: '2026-05-01T00:00:00Z',
  disabled_at: null,
}

const sampleDelivery = {
  id: 'whd_1',
  event_name: 'order.completed',
  response_code: 200,
  success: true,
  created_at: '2026-05-01T00:00:00Z',
  updated_at: '2026-05-01T00:00:00Z',
  webhook_endpoint_id: 'whe_abc123',
}

describe('webhookEndpoints', () => {
  describe('list / get', () => {
    it('GETs /webhook_endpoints with Ransack filters', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/webhook_endpoints`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(paginated([sampleEndpoint]))
        }),
      )

      const res = await createTestClient().webhookEndpoints.list({ active_eq: true })

      expect(res.data[0]?.id).toBe('whe_abc123')
      expect(url!.searchParams.get('q[active_eq]')).toBe('true')
    })

    it('GETs /webhook_endpoints/:id and forwards expand params', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/webhook_endpoints/whe_abc123`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(sampleEndpoint)
        }),
      )

      const res = await createTestClient().webhookEndpoints.get('whe_abc123', {
        expand: ['deliveries'],
      })

      expect(res.url).toBe('https://example.com/hooks')
      expect(url!.searchParams.get('expand')).toBe('deliveries')
    })
  })

  describe('create / update / delete', () => {
    it('POSTs the create body verbatim', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(`${API_PREFIX}/webhook_endpoints`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json(sampleEndpoint, { status: 201 })
        }),
      )

      await createTestClient().webhookEndpoints.create({
        url: 'https://example.com/hooks',
        subscriptions: ['order.completed'],
      })

      expect(body).toEqual({
        url: 'https://example.com/hooks',
        subscriptions: ['order.completed'],
      })
    })

    it('PATCHes the update body verbatim', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.patch(`${API_PREFIX}/webhook_endpoints/whe_abc123`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json({ ...sampleEndpoint, name: 'Staging' })
        }),
      )

      const res = await createTestClient().webhookEndpoints.update('whe_abc123', {
        name: 'Staging',
      })

      expect(body).toEqual({ name: 'Staging' })
      expect(res.name).toBe('Staging')
    })

    it('DELETEs /webhook_endpoints/:id', async () => {
      let hit = false
      server.use(
        http.delete(`${API_PREFIX}/webhook_endpoints/whe_abc123`, () => {
          hit = true
          return new HttpResponse(null, { status: 204 })
        }),
      )

      await expect(
        createTestClient().webhookEndpoints.delete('whe_abc123'),
      ).resolves.toBeUndefined()
      expect(hit).toBe(true)
    })
  })

  describe('sendTest', () => {
    it('POSTs /webhook_endpoints/:id/send_test and returns a delivery', async () => {
      let hit = false
      server.use(
        http.post(`${API_PREFIX}/webhook_endpoints/whe_abc123/send_test`, () => {
          hit = true
          return HttpResponse.json(sampleDelivery, { status: 201 })
        }),
      )

      const res = await createTestClient().webhookEndpoints.sendTest('whe_abc123')

      expect(hit).toBe(true)
      expect(res.id).toBe('whd_1')
    })
  })

  describe('enable / disable', () => {
    it('PATCHes /enable', async () => {
      let hit = false
      server.use(
        http.patch(`${API_PREFIX}/webhook_endpoints/whe_abc123/enable`, () => {
          hit = true
          return HttpResponse.json({ ...sampleEndpoint, active: true })
        }),
      )

      const res = await createTestClient().webhookEndpoints.enable('whe_abc123')

      expect(hit).toBe(true)
      expect(res.active).toBe(true)
    })

    it('PATCHes /disable with the reason body', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.patch(`${API_PREFIX}/webhook_endpoints/whe_abc123/disable`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json({
            ...sampleEndpoint,
            active: false,
            disabled_reason: 'too many failures',
          })
        }),
      )

      const res = await createTestClient().webhookEndpoints.disable('whe_abc123', {
        reason: 'too many failures',
      })

      expect(body).toEqual({ reason: 'too many failures' })
      expect(res.active).toBe(false)
    })
  })

  describe('nested deliveries', () => {
    it('GETs /webhook_endpoints/:eid/deliveries with Ransack filters', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/webhook_endpoints/whe_abc123/deliveries`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(paginated([sampleDelivery]))
        }),
      )

      const res = await createTestClient().webhookEndpoints.deliveries.list('whe_abc123', {
        success_eq: false,
      })

      expect(res.data[0]?.id).toBe('whd_1')
      expect(url!.searchParams.get('q[success_eq]')).toBe('false')
    })

    it('GETs a single delivery by id', async () => {
      server.use(
        http.get(`${API_PREFIX}/webhook_endpoints/whe_abc123/deliveries/whd_1`, () =>
          HttpResponse.json(sampleDelivery),
        ),
      )

      const res = await createTestClient().webhookEndpoints.deliveries.get('whe_abc123', 'whd_1')

      expect(res.event_name).toBe('order.completed')
    })

    it('POSTs /deliveries/:id/redeliver', async () => {
      let hit = false
      server.use(
        http.post(`${API_PREFIX}/webhook_endpoints/whe_abc123/deliveries/whd_1/redeliver`, () => {
          hit = true
          return HttpResponse.json({ ...sampleDelivery, id: 'whd_2' }, { status: 201 })
        }),
      )

      const res = await createTestClient().webhookEndpoints.deliveries.redeliver(
        'whe_abc123',
        'whd_1',
      )

      expect(hit).toBe(true)
      expect(res.id).toBe('whd_2')
    })
  })
})
