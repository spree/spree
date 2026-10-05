import { describe, expect, it } from 'vitest'
import {
  adjustmentTiersFormValues,
  PRICE_LIST_DEFAULTS,
  priceListFormSchema,
  priceListValuesToParams,
} from './price-list'

describe('priceListValuesToParams', () => {
  it('sends quantity tiers signed by the chosen direction', () => {
    const params = priceListValuesToParams({
      ...PRICE_LIST_DEFAULTS,
      name: 'Volume',
      adjustment_direction: 'decrease',
      adjustment_tiers: [{ min_quantity: '10', percentage: '10' }],
    })

    expect(params.price_adjustment_tiers).toEqual([{ min_quantity: 10, percentage: '-10' }])
  })

  it('sends an empty ladder so removed tiers are cleared', () => {
    expect(
      priceListValuesToParams({ ...PRICE_LIST_DEFAULTS, name: 'Volume' }).price_adjustment_tiers,
    ).toEqual([])
  })
})

describe('adjustmentTiersFormValues', () => {
  it('reads stored tiers back as a direction and magnitudes', () => {
    expect(
      adjustmentTiersFormValues([
        { id: 'pat_1', min_quantity: 10, percentage: '-10.0' },
        { id: 'pat_2', min_quantity: 50, percentage: '-20.0' },
      ] as never),
    ).toEqual({
      adjustment_direction: 'decrease',
      adjustment_tiers: [
        { min_quantity: '10', percentage: '10' },
        { min_quantity: '50', percentage: '20' },
      ],
    })
  })
})

describe('priceListFormSchema', () => {
  const values = (tiers: { min_quantity: string; percentage: string }[]) => ({
    ...PRICE_LIST_DEFAULTS,
    name: 'Volume',
    adjustment_tiers: tiers,
  })

  it('refuses a tier at a single unit or a repeated quantity', () => {
    expect(
      priceListFormSchema.safeParse(values([{ min_quantity: '1', percentage: '5' }])).success,
    ).toBe(false)
    expect(
      priceListFormSchema.safeParse(
        values([
          { min_quantity: '10', percentage: '5' },
          { min_quantity: '10', percentage: '10' },
        ]),
      ).success,
    ).toBe(false)
  })

  it('refuses a discount of 100% or more', () => {
    expect(
      priceListFormSchema.safeParse(values([{ min_quantity: '10', percentage: '100' }])).success,
    ).toBe(false)
  })

  it('accepts a well-formed ladder', () => {
    expect(
      priceListFormSchema.safeParse(values([{ min_quantity: '10', percentage: '10' }])).success,
    ).toBe(true)
  })
})
