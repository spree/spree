import type { PriceList } from '@spree/admin-sdk'
import { describe, expect, it } from 'vitest'
import {
  CATALOG_DEFAULTS,
  type CatalogFormValues,
  catalogPricingValues,
  catalogValuesToParams,
} from './catalog'

type OwnedList = Pick<
  PriceList,
  'price_adjustment_percentage' | 'adjust_compare_at' | 'price_rules' | 'price_adjustment_tiers'
>

// A discount from ten units and a markup from fifty — a ladder the Admin API
// accepts but the form's single direction control cannot express.
const MIXED_SIGN_TIERS = [
  { min_quantity: 10, percentage: '-10.0' },
  { min_quantity: 50, percentage: '5.0' },
] as OwnedList['price_adjustment_tiers']

function ownedList(overrides: Partial<OwnedList> = {}): OwnedList {
  return {
    price_adjustment_percentage: null,
    adjust_compare_at: false,
    price_rules: [],
    price_adjustment_tiers: MIXED_SIGN_TIERS,
    ...overrides,
  } as OwnedList
}

function loadedForm(list: OwnedList) {
  const loaded = catalogPricingValues(list)
  const values: CatalogFormValues = { ...CATALOG_DEFAULTS, name: 'Wholesale', ...loaded }
  return { loaded, values }
}

describe('catalogValuesToParams', () => {
  it('leaves a mixed-sign ladder alone when only the name changes', () => {
    const { loaded, values } = loadedForm(ownedList())

    const params = catalogValuesToParams({ ...values, name: 'Wholesale 2027' }, loaded)

    expect(params.name).toBe('Wholesale 2027')
    expect(params.price_list).not.toHaveProperty('price_adjustment_tiers')
  })

  it('leaves the ladder alone beside a percentage of its own', () => {
    const { loaded, values } = loadedForm(ownedList({ price_adjustment_percentage: '-5.0' }))

    const params = catalogValuesToParams({ ...values, name: 'Renamed' }, loaded)

    expect(params.price_list).toMatchObject({ price_adjustment_percentage: '-5' })
    expect(params.price_list).not.toHaveProperty('price_adjustment_tiers')
  })

  it('sends the whole ladder once a band is edited', () => {
    const { loaded, values } = loadedForm(ownedList())

    const params = catalogValuesToParams(
      {
        ...values,
        adjustment_tiers: [
          { min_quantity: '10', percentage: '15' },
          { min_quantity: '50', percentage: '5' },
        ],
      },
      loaded,
    )

    expect(params.price_list).toMatchObject({
      price_adjustment_tiers: [
        { min_quantity: 10, percentage: '-15' },
        { min_quantity: 50, percentage: '-5' },
      ],
    })
  })

  it('sends the whole ladder once the direction is flipped', () => {
    const { loaded, values } = loadedForm(ownedList())

    const params = catalogValuesToParams({ ...values, adjustment_direction: 'increase' }, loaded)

    expect(params.price_list).toMatchObject({
      price_adjustment_tiers: [
        { min_quantity: 10, percentage: '10' },
        { min_quantity: 50, percentage: '5' },
      ],
    })
  })

  it('still clears the ladder when switching to fixed prices', () => {
    const { loaded, values } = loadedForm(ownedList())

    const params = catalogValuesToParams({ ...values, pricing_mode: 'fixed' }, loaded)

    expect(params.price_list).toMatchObject({
      price_adjustment_percentage: null,
      price_adjustment_tiers: [],
    })
  })

  it('sends the ladder when there is nothing loaded to compare against', () => {
    const { values } = loadedForm(ownedList())

    const params = catalogValuesToParams(values)

    expect(params.price_list).toMatchObject({
      price_adjustment_tiers: [
        { min_quantity: 10, percentage: '-10' },
        { min_quantity: 50, percentage: '-5' },
      ],
    })
  })
})
