import { HttpResponse, http } from 'msw'
import { describe, expect, it } from 'vitest'
import { API_PREFIX, createTestClient, paginated } from './helpers'
import { server } from './mocks/server'

const samplePromotion = {
  id: 'promo_abc123',
  name: 'Summer Sale',
  code: 'SUMMER',
  description: null,
  starts_at: null,
  expires_at: null,
  created_at: '2026-05-01T00:00:00Z',
  updated_at: '2026-05-01T00:00:00Z',
}

const samplePromotionAction = {
  id: 'promoact_1',
  type: 'Spree::Promotion::Actions::CreateItemAdjustments',
  calculator_type: 'Spree::Calculator::FlatRate',
}

const samplePromotionRule = {
  id: 'promorule_1',
  type: 'Spree::Promotion::Rules::ItemTotal',
}

const sampleCouponCode = { id: 'coupon_1', code: 'SUMMER10', state: 'pending' }

describe('promotions', () => {
  describe('list', () => {
    it('GETs /promotions and returns paginated data', async () => {
      server.use(
        http.get(`${API_PREFIX}/promotions`, () => HttpResponse.json(paginated([samplePromotion]))),
      )

      const res = await createTestClient().promotions.list()

      expect(res.data).toHaveLength(1)
      expect(res.data[0]?.id).toBe('promo_abc123')
    })

    it('wraps Ransack predicates via transformListParams', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/promotions`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(paginated([]))
        }),
      )

      await createTestClient().promotions.list({ name_cont: 'summer', code_eq: 'SUMMER' })

      expect(url!.searchParams.get('q[name_cont]')).toBe('summer')
      expect(url!.searchParams.get('q[code_eq]')).toBe('SUMMER')
    })
  })

  describe('get', () => {
    it('GETs /promotions/:id and forwards expand params', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/promotions/promo_abc123`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(samplePromotion)
        }),
      )

      const res = await createTestClient().promotions.get('promo_abc123', {
        expand: ['promotion_actions'],
      })

      expect(res.id).toBe('promo_abc123')
      expect(url!.searchParams.get('expand')).toBe('promotion_actions')
    })
  })

  describe('create / update / delete', () => {
    it('POSTs the create body verbatim', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(`${API_PREFIX}/promotions`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json(samplePromotion, { status: 201 })
        }),
      )

      await createTestClient().promotions.create({ name: 'Summer Sale', code: 'SUMMER' })

      expect(body).toEqual({ name: 'Summer Sale', code: 'SUMMER' })
    })

    it('PATCHes the update body verbatim', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.patch(`${API_PREFIX}/promotions/promo_abc123`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json({ ...samplePromotion, name: 'Autumn Sale' })
        }),
      )

      const res = await createTestClient().promotions.update('promo_abc123', {
        name: 'Autumn Sale',
      })

      expect(body).toEqual({ name: 'Autumn Sale' })
      expect(res.name).toBe('Autumn Sale')
    })

    it('DELETEs /promotions/:id', async () => {
      let hit = false
      server.use(
        http.delete(`${API_PREFIX}/promotions/promo_abc123`, () => {
          hit = true
          return new HttpResponse(null, { status: 204 })
        }),
      )

      await expect(createTestClient().promotions.delete('promo_abc123')).resolves.toBeUndefined()
      expect(hit).toBe(true)
    })
  })

  describe('nested actions', () => {
    it('GETs /promotions/:pid/promotion_actions', async () => {
      server.use(
        http.get(`${API_PREFIX}/promotions/promo_abc123/promotion_actions`, () =>
          HttpResponse.json(paginated([samplePromotionAction])),
        ),
      )

      const res = await createTestClient().promotions.actions.list('promo_abc123')

      expect(res.data[0]?.id).toBe('promoact_1')
    })

    it('POSTs a promotion action verbatim', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(
          `${API_PREFIX}/promotions/promo_abc123/promotion_actions`,
          async ({ request }) => {
            body = (await request.json()) as Record<string, unknown>
            return HttpResponse.json(samplePromotionAction, { status: 201 })
          },
        ),
      )

      await createTestClient().promotions.actions.create('promo_abc123', {
        type: 'Spree::Promotion::Actions::CreateItemAdjustments',
        calculator_type: 'Spree::Calculator::FlatRate',
      })

      expect(body).toEqual({
        type: 'Spree::Promotion::Actions::CreateItemAdjustments',
        calculator_type: 'Spree::Calculator::FlatRate',
      })
    })

    it('DELETEs a promotion action', async () => {
      let hit = false
      server.use(
        http.delete(`${API_PREFIX}/promotions/promo_abc123/promotion_actions/promoact_1`, () => {
          hit = true
          return new HttpResponse(null, { status: 204 })
        }),
      )

      await createTestClient().promotions.actions.delete('promo_abc123', 'promoact_1')
      expect(hit).toBe(true)
    })
  })

  describe('nested rules', () => {
    it('GETs /promotions/:pid/promotion_rules', async () => {
      server.use(
        http.get(`${API_PREFIX}/promotions/promo_abc123/promotion_rules`, () =>
          HttpResponse.json(paginated([samplePromotionRule])),
        ),
      )

      const res = await createTestClient().promotions.rules.list('promo_abc123')

      expect(res.data[0]?.id).toBe('promorule_1')
    })

    it('POSTs a promotion rule verbatim', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(`${API_PREFIX}/promotions/promo_abc123/promotion_rules`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json(samplePromotionRule, { status: 201 })
        }),
      )

      await createTestClient().promotions.rules.create('promo_abc123', {
        type: 'Spree::Promotion::Rules::ItemTotal',
      })

      expect(body).toEqual({ type: 'Spree::Promotion::Rules::ItemTotal' })
    })

    it('DELETEs a promotion rule', async () => {
      let hit = false
      server.use(
        http.delete(`${API_PREFIX}/promotions/promo_abc123/promotion_rules/promorule_1`, () => {
          hit = true
          return new HttpResponse(null, { status: 204 })
        }),
      )

      await createTestClient().promotions.rules.delete('promo_abc123', 'promorule_1')
      expect(hit).toBe(true)
    })
  })

  describe('nested coupon codes', () => {
    it('GETs /promotions/:pid/coupon_codes', async () => {
      server.use(
        http.get(`${API_PREFIX}/promotions/promo_abc123/coupon_codes`, () =>
          HttpResponse.json(paginated([sampleCouponCode])),
        ),
      )

      const res = await createTestClient().promotions.couponCodes.list('promo_abc123')

      expect(res.data[0]?.id).toBe('coupon_1')
    })

    it('GETs a single coupon code by id', async () => {
      server.use(
        http.get(`${API_PREFIX}/promotions/promo_abc123/coupon_codes/coupon_1`, () =>
          HttpResponse.json(sampleCouponCode),
        ),
      )

      const res = await createTestClient().promotions.couponCodes.get('promo_abc123', 'coupon_1')

      expect(res.code).toBe('SUMMER10')
    })
  })
})

describe('promotionActions', () => {
  describe('types', () => {
    it('GETs /promotion_actions/types', async () => {
      server.use(
        http.get(`${API_PREFIX}/promotion_actions/types`, () =>
          HttpResponse.json({
            data: [
              {
                type: 'Spree::Promotion::Actions::CreateItemAdjustments',
                label: 'Create Item Adjustments',
              },
            ],
          }),
        ),
      )

      const res = await createTestClient().promotionActions.types()

      expect(res.data).toHaveLength(1)
      expect(res.data[0]?.type).toBe('Spree::Promotion::Actions::CreateItemAdjustments')
    })
  })

  describe('calculators', () => {
    it('GETs /promotion_actions/calculators with the type param', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/promotion_actions/calculators`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json({
            data: [{ type: 'Spree::Calculator::FlatRate', label: 'Flat Rate' }],
          })
        }),
      )

      const res = await createTestClient().promotionActions.calculators(
        'Spree::Promotion::Actions::CreateItemAdjustments',
      )

      expect(url!.searchParams.get('type')).toBe('Spree::Promotion::Actions::CreateItemAdjustments')
      expect(res.data[0]?.type).toBe('Spree::Calculator::FlatRate')
    })
  })
})

describe('promotionRules', () => {
  describe('types', () => {
    it('GETs /promotion_rules/types', async () => {
      server.use(
        http.get(`${API_PREFIX}/promotion_rules/types`, () =>
          HttpResponse.json({
            data: [{ type: 'Spree::Promotion::Rules::ItemTotal', label: 'Item Total' }],
          }),
        ),
      )

      const res = await createTestClient().promotionRules.types()

      expect(res.data).toHaveLength(1)
      expect(res.data[0]?.type).toBe('Spree::Promotion::Rules::ItemTotal')
    })
  })
})
