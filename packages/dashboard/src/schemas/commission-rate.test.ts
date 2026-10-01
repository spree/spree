import type { CommissionRate } from '@spree/admin-sdk'
import { describe, expect, it } from 'vitest'
import { commissionRateToFormValues, commissionRateValuesToParams } from './commission-rate'

function commissionRateStub(rules: CommissionRate['rules']): CommissionRate {
  return {
    id: 'crate_1',
    name: 'Audio',
    code: null,
    enabled: true,
    position: 1,
    kind: 'percentage',
    value: '10',
    tax_inclusive: false,
    include_shipping: false,
    commission_tax_rate: null,
    metadata: null,
    deleted_at: null,
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
    amounts: {},
    bounds: {},
    global: false,
    rules,
  }
}

describe('commissionRateToFormValues', () => {
  it('seeds seller and category pickers from prefixed top-level ids', () => {
    const rate = commissionRateStub([
      {
        id: 'comrule_1',
        type: 'seller_rule',
        commission_rate_id: 'crate_1',
        preferences: { seller_ids: [42] },
        preference_schema: [],
        created_at: '2026-01-01T00:00:00Z',
        updated_at: '2026-01-01T00:00:00Z',
        product_ids: null,
        seller_ids: ['sel_abc'],
        category_ids: null,
      },
      {
        id: 'comrule_2',
        type: 'category_rule',
        commission_rate_id: 'crate_1',
        preferences: { category_ids: [7] },
        preference_schema: [],
        created_at: '2026-01-01T00:00:00Z',
        updated_at: '2026-01-01T00:00:00Z',
        product_ids: null,
        seller_ids: null,
        category_ids: ['ctg_xyz'],
      },
    ])

    const values = commissionRateToFormValues(rate)

    expect(values.rules[0]?.seller_ids).toEqual(['sel_abc'])
    expect(values.rules[0]?.preferences).toEqual({})
    expect(values.rules[1]?.category_ids).toEqual(['ctg_xyz'])
    expect(values.rules[1]?.preferences).toEqual({})
  })
})

describe('commissionRateValuesToParams', () => {
  it('writes seller and category ids back into preferences as prefixed ids', () => {
    const params = commissionRateValuesToParams({
      name: 'Audio',
      code: '',
      enabled: true,
      kind: 'percentage',
      value: 10,
      amounts: {},
      bounds: {},
      tax_inclusive: false,
      include_shipping: false,
      commission_tax_rate: '',
      rules: [
        {
          type: 'seller_rule',
          preferences: {},
          product_ids: [],
          seller_ids: ['sel_abc'],
          category_ids: [],
        },
        {
          type: 'category_rule',
          preferences: {},
          product_ids: [],
          seller_ids: [],
          category_ids: ['ctg_xyz'],
        },
      ],
    })

    expect(params.rules?.[0]?.preferences).toEqual({ seller_ids: ['sel_abc'] })
    expect(params.rules?.[1]?.preferences).toEqual({ category_ids: ['ctg_xyz'] })
  })
})
