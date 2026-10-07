import { describe, expect, it } from 'vitest'
import {
  prepareVariantsTaxForProductSave,
  variantHasTaxCategoryOverride,
  variantToFormValues,
  variantToWirePayload,
} from './product-form-mapping'
import type { VariantFormValues } from './product-schema'
import type { PanelVariant } from './product-types'

// variantToFormValues reads a handful of fields; cast a minimal fixture rather
// than fabricating the whole serialized variant it ignores.
function variantWith(prices: PanelVariant['prices']): PanelVariant {
  return { id: 'variant_1', sku: 'ESP-SEMI', option_values: [], prices } as unknown as PanelVariant
}

describe('variantToFormValues prices', () => {
  it('keeps the shop price in each currency', () => {
    const values = variantToFormValues(
      variantWith([
        { currency: 'USD', amount: '549.99', price_list_id: null },
        { currency: 'EUR', amount: '509.99', price_list_id: null },
      ]),
      0,
    )

    expect(values.prices).toEqual([
      { currency: 'USD', amount: '549.99', compare_at_amount: null },
      { currency: 'EUR', amount: '509.99', compare_at_amount: null },
    ])
  })

  // The form posts this array straight back as the variant's base prices, so a
  // price-list row taken in here returns as the shop price and overwrites it —
  // and a list's null-amount placeholder returns as "no price" and deletes it.
  it('drops what a price list charges, whatever order the rows arrive in', () => {
    const values = variantToFormValues(
      variantWith([
        { currency: 'USD', amount: '329.99', price_list_id: 'pl_1' },
        { currency: 'USD', amount: '549.99', price_list_id: null },
        { currency: 'EUR', amount: null, price_list_id: 'pl_1' },
        { currency: 'EUR', amount: '509.99', price_list_id: null },
        { currency: 'USD', amount: '249.99', price_list_id: 'pl_1' },
      ]),
      0,
    )

    expect(values.prices).toEqual([
      { currency: 'USD', amount: '549.99', compare_at_amount: null },
      { currency: 'EUR', amount: '509.99', compare_at_amount: null },
    ])
  })

  it('ships only the shop prices back to the API', () => {
    const values = variantToFormValues(
      variantWith([
        { currency: 'USD', amount: '549.99', price_list_id: null },
        { currency: 'USD', amount: '329.99', price_list_id: 'pl_1' },
      ]),
      0,
    )

    expect(variantToWirePayload(values, 0).prices).toEqual([
      { currency: 'USD', amount: '549.99', compare_at_amount: null },
    ])
  })

  // A variant a price list prices but the shop does not has no shop price, and
  // an empty array is how the form says so.
  it('leaves no price when only a price list prices the variant', () => {
    const values = variantToFormValues(
      variantWith([{ currency: 'USD', amount: '89.99', price_list_id: 'pl_1' }]),
      0,
    )

    expect(values.prices).toEqual([])
  })
})

describe('variant tax category overrides', () => {
  const baseVariant = (): VariantFormValues => ({
    id: 'variant_1',
    sku: 'SKU-1',
    barcode: null,
    position: 0,
    options: [],
    weight: null,
    height: null,
    width: null,
    depth: null,
    weight_unit: null,
    dimensions_unit: null,
    hs_code: null,
    country_of_origin: null,
    customs_description: null,
    minimum_order_quantity: null,
    order_multiple: null,
    purchase_unit: null,
    units_per_carton: null,
    cartons_per_pallet: null,
    carton_weight: null,
    carton_package_type_id: null,
    track_inventory: true,
    preorderable: false,
    preorder_ships_at: null,
    backorder_limit: null,
    tax_category_id: null,
    prices: [],
    stock_levels: [],
  })

  it('detects a stored override', () => {
    expect(variantHasTaxCategoryOverride({ ...baseVariant(), tax_category_id: 'taxcat_1' })).toBe(
      true,
    )
    expect(variantHasTaxCategoryOverride(baseVariant())).toBe(false)
  })

  it('clears inheriting variants and keeps overrides on save prep', () => {
    const variants = [
      { ...baseVariant(), tax_category_id: null },
      { ...baseVariant(), id: 'variant_2', tax_category_id: 'taxcat_override' },
    ]

    const prepared = prepareVariantsTaxForProductSave(variants, 'taxcat_product')

    expect(prepared[0].tax_category_id).toBeNull()
    expect(prepared[1].tax_category_id).toBe('taxcat_override')
    expect(variantToWirePayload(prepared[0], 0).tax_category_id).toBeNull()
  })
})
