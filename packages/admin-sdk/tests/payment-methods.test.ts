import { HttpResponse, http } from 'msw'
import { describe, expect, it } from 'vitest'
import { API_PREFIX, createTestClient, paginated } from './helpers'
import { server } from './mocks/server'

const samplePaymentMethod = {
  id: 'pm_1',
  type: 'bogus',
  name: 'Credit Card',
  description: 'Pay by card',
  active: true,
  storefront_visible: true,
  auto_capture: null,
  position: 1,
  created_at: '2026-05-01T00:00:00Z',
  updated_at: '2026-05-01T00:00:00Z',
}

describe('paymentMethods', () => {
  describe('list', () => {
    it('GETs /payment_methods and returns paginated data', async () => {
      server.use(
        http.get(`${API_PREFIX}/payment_methods`, () =>
          HttpResponse.json(paginated([samplePaymentMethod])),
        ),
      )

      const res = await createTestClient().paymentMethods.list()

      expect(res.data).toHaveLength(1)
      expect(res.data[0]?.id).toBe('pm_1')
    })

    it('wraps Ransack predicates via transformListParams', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/payment_methods`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(paginated([]))
        }),
      )

      await createTestClient().paymentMethods.list({ active_eq: true, name_cont: 'card' })

      expect(url!.searchParams.get('q[active_eq]')).toBe('true')
      expect(url!.searchParams.get('q[name_cont]')).toBe('card')
    })
  })

  describe('get', () => {
    it('GETs /payment_methods/:id and forwards expand params', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/payment_methods/pm_1`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(samplePaymentMethod)
        }),
      )

      const res = await createTestClient().paymentMethods.get('pm_1', { expand: ['stores'] })

      expect(res.id).toBe('pm_1')
      expect(url!.searchParams.get('expand')).toBe('stores')
    })
  })

  describe('create / update / delete', () => {
    it('POSTs the create body verbatim', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(`${API_PREFIX}/payment_methods`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json(samplePaymentMethod, { status: 201 })
        }),
      )

      await createTestClient().paymentMethods.create({
        type: 'bogus',
        name: 'Credit Card',
      })

      expect(body).toEqual({ type: 'bogus', name: 'Credit Card' })
    })

    it('PATCHes the update body verbatim', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.patch(`${API_PREFIX}/payment_methods/pm_1`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json({ ...samplePaymentMethod, name: 'PayPal' })
        }),
      )

      const res = await createTestClient().paymentMethods.update('pm_1', { name: 'PayPal' })

      expect(body).toEqual({ name: 'PayPal' })
      expect(res.name).toBe('PayPal')
    })

    it('DELETEs /payment_methods/:id', async () => {
      let hit = false
      server.use(
        http.delete(`${API_PREFIX}/payment_methods/pm_1`, () => {
          hit = true
          return new HttpResponse(null, { status: 204 })
        }),
      )

      await expect(createTestClient().paymentMethods.delete('pm_1')).resolves.toBeUndefined()
      expect(hit).toBe(true)
    })
  })

  describe('types', () => {
    it('GETs /payment_methods/types with preference schema', async () => {
      let hit = false
      server.use(
        http.get(`${API_PREFIX}/payment_methods/types`, () => {
          hit = true
          return HttpResponse.json({
            data: [
              {
                type: 'bogus',
                label: 'Bogus Gateway',
                description: 'Test gateway for development',
                schema: {
                  type: 'object',
                  properties: { server: { type: 'string', default: 'test' } },
                  additionalProperties: false,
                },
              },
            ],
          })
        }),
      )

      const res = await createTestClient().paymentMethods.types()

      expect(hit).toBe(true)
      expect(res.data).toHaveLength(1)
      expect(res.data[0]?.type).toBe('bogus')
    })
  })

  describe('rules', () => {
    const sampleRule = {
      id: 'pmrule_1',
      type: 'channel_rule',
      active: true,
      preferences: { channel_ids: ['ch_1'] },
      created_at: '2026-05-01T00:00:00Z',
      updated_at: '2026-05-01T00:00:00Z',
    }

    it('GETs /payment_methods/:id/rules', async () => {
      server.use(
        http.get(`${API_PREFIX}/payment_methods/pm_1/rules`, () =>
          HttpResponse.json(paginated([sampleRule])),
        ),
      )

      const res = await createTestClient().paymentMethods.rules.list('pm_1')

      expect(res.data[0]?.type).toBe('channel_rule')
    })

    it('POSTs and PATCHes rule bodies verbatim', async () => {
      const bodies: Array<Record<string, unknown>> = []
      server.use(
        http.post(`${API_PREFIX}/payment_methods/pm_1/rules`, async ({ request }) => {
          bodies.push((await request.json()) as Record<string, unknown>)
          return HttpResponse.json(sampleRule, { status: 201 })
        }),
        http.patch(`${API_PREFIX}/payment_methods/pm_1/rules/pmrule_1`, async ({ request }) => {
          bodies.push((await request.json()) as Record<string, unknown>)
          return HttpResponse.json({ ...sampleRule, active: false })
        }),
      )

      const client = createTestClient()
      await client.paymentMethods.rules.create('pm_1', {
        type: 'channel_rule',
        preferences: { channel_ids: ['ch_1'] },
      })
      const updated = await client.paymentMethods.rules.update('pm_1', 'pmrule_1', {
        active: false,
      })

      expect(bodies).toEqual([
        { type: 'channel_rule', preferences: { channel_ids: ['ch_1'] } },
        { active: false },
      ])
      expect(updated.active).toBe(false)
    })

    it('DELETEs a rule and GETs the rule types', async () => {
      let deleted = false
      server.use(
        http.delete(`${API_PREFIX}/payment_methods/pm_1/rules/pmrule_1`, () => {
          deleted = true
          return new HttpResponse(null, { status: 204 })
        }),
        http.get(`${API_PREFIX}/payment_method_rules/types`, () =>
          HttpResponse.json({
            data: [
              { type: 'market_rule', label: 'Market', description: '', schema: { type: 'object' } },
            ],
          }),
        ),
      )

      const client = createTestClient()
      await client.paymentMethods.rules.delete('pm_1', 'pmrule_1')
      const types = await client.paymentMethods.ruleTypes()

      expect(deleted).toBe(true)
      expect(types.data[0]?.type).toBe('market_rule')
    })
  })
})
