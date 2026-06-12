import { HttpResponse, http } from 'msw'
import { describe, expect, it } from 'vitest'
import { API_PREFIX, createTestClient, paginated } from './helpers'
import { server } from './mocks/server'

const sampleCustomerGroup = {
  id: 'cg_abc123',
  name: 'VIP',
  description: null,
  customers_count: 0,
  created_at: '2026-05-01T00:00:00Z',
  updated_at: '2026-05-01T00:00:00Z',
}

describe('customerGroups', () => {
  describe('list', () => {
    it('GETs /customer_groups and returns paginated data', async () => {
      server.use(
        http.get(`${API_PREFIX}/customer_groups`, () =>
          HttpResponse.json(paginated([sampleCustomerGroup])),
        ),
      )

      const res = await createTestClient().customerGroups.list()

      expect(res.data).toHaveLength(1)
      expect(res.data[0]?.id).toBe('cg_abc123')
    })

    it('wraps Ransack predicates via transformListParams', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/customer_groups`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(paginated([]))
        }),
      )

      await createTestClient().customerGroups.list({ name_cont: 'vip', name_eq: 'VIP' })

      expect(url!.searchParams.get('q[name_cont]')).toBe('vip')
      expect(url!.searchParams.get('q[name_eq]')).toBe('VIP')
    })
  })

  describe('get', () => {
    it('GETs /customer_groups/:id and forwards expand params', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/customer_groups/cg_abc123`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(sampleCustomerGroup)
        }),
      )

      const res = await createTestClient().customerGroups.get('cg_abc123', {
        expand: ['customers'],
      })

      expect(res.id).toBe('cg_abc123')
      expect(url!.searchParams.get('expand')).toBe('customers')
    })
  })

  describe('create / update / delete', () => {
    it('POSTs the create body verbatim', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(`${API_PREFIX}/customer_groups`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json(sampleCustomerGroup, { status: 201 })
        }),
      )

      await createTestClient().customerGroups.create({ name: 'VIP', description: 'Top spenders' })

      expect(body).toEqual({ name: 'VIP', description: 'Top spenders' })
    })

    it('PATCHes the update body verbatim', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.patch(`${API_PREFIX}/customer_groups/cg_abc123`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json({ ...sampleCustomerGroup, name: 'Wholesale' })
        }),
      )

      const res = await createTestClient().customerGroups.update('cg_abc123', { name: 'Wholesale' })

      expect(body).toEqual({ name: 'Wholesale' })
      expect(res.name).toBe('Wholesale')
    })

    it('DELETEs /customer_groups/:id', async () => {
      let hit = false
      server.use(
        http.delete(`${API_PREFIX}/customer_groups/cg_abc123`, () => {
          hit = true
          return new HttpResponse(null, { status: 204 })
        }),
      )

      await expect(createTestClient().customerGroups.delete('cg_abc123')).resolves.toBeUndefined()
      expect(hit).toBe(true)
    })
  })
})
