import { HttpResponse, http } from 'msw'
import { describe, expect, it } from 'vitest'
import { API_PREFIX, createTestClient, paginated } from './helpers'
import { server } from './mocks/server'

const sampleRule = {
  id: 'orule_abc123',
  type: 'preferred_location',
  channel_id: 'ch_abc123',
  position: 1,
  active: true,
  label: 'Preferred location',
  description: 'Fulfill from the location pinned on the order, when one is set',
  preferences: {},
  preference_schema: [],
  created_at: '2026-07-01T00:00:00Z',
  updated_at: '2026-07-01T00:00:00Z',
}

describe('channels.orderRoutingRules', () => {
  it('GETs /channels/:channelId/order_routing_rules', async () => {
    server.use(
      http.get(`${API_PREFIX}/channels/ch_abc123/order_routing_rules`, () =>
        HttpResponse.json(paginated([sampleRule])),
      ),
    )

    const res = await createTestClient().channels.orderRoutingRules.list('ch_abc123')

    expect(res.data).toHaveLength(1)
    expect(res.data[0]?.id).toBe('orule_abc123')
  })

  it('POSTs the create body verbatim', async () => {
    let body: unknown
    server.use(
      http.post(`${API_PREFIX}/channels/ch_abc123/order_routing_rules`, async ({ request }) => {
        body = await request.json()
        return HttpResponse.json(sampleRule, { status: 201 })
      }),
    )

    await createTestClient().channels.orderRoutingRules.create('ch_abc123', {
      type: 'preferred_location',
    })

    expect(body).toEqual({ type: 'preferred_location' })
  })

  it('PATCHes active and position updates', async () => {
    let body: unknown
    server.use(
      http.patch(
        `${API_PREFIX}/channels/ch_abc123/order_routing_rules/orule_abc123`,
        async ({ request }) => {
          body = await request.json()
          return HttpResponse.json({ ...sampleRule, active: false, position: 2 })
        },
      ),
    )

    const res = await createTestClient().channels.orderRoutingRules.update(
      'ch_abc123',
      'orule_abc123',
      { active: false, position: 2 },
    )

    expect(body).toEqual({ active: false, position: 2 })
    expect(res.active).toBe(false)
  })

  it('DELETEs and resolves on 204', async () => {
    server.use(
      http.delete(
        `${API_PREFIX}/channels/ch_abc123/order_routing_rules/orule_abc123`,
        () => new HttpResponse(null, { status: 204 }),
      ),
    )

    await expect(
      createTestClient().channels.orderRoutingRules.delete('ch_abc123', 'orule_abc123'),
    ).resolves.toBeUndefined()
  })
})

describe('orderRoutingRules', () => {
  describe('types', () => {
    it('GETs /order_routing_rules/types', async () => {
      server.use(
        http.get(`${API_PREFIX}/order_routing_rules/types`, () =>
          HttpResponse.json({
            data: [
              {
                type: 'preferred_location',
                label: 'Preferred location',
                description: null,
                preference_schema: [],
              },
            ],
          }),
        ),
      )

      const res = await createTestClient().orderRoutingRules.types()

      expect(res.data).toHaveLength(1)
      expect(res.data[0]?.type).toBe('preferred_location')
    })
  })
})
