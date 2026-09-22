import type { StockLevel } from '@spree/admin-sdk'
import { describe, expect, it } from 'vitest'
import { mergeStockLevelUpdate } from './use-stock-levels'

function stockLevel(overrides: Partial<StockLevel> = {}): StockLevel {
  return {
    id: 'stlv_1',
    count_on_hand: 10,
    backorderable: false,
    stock_location_id: 'sloc_1',
    variant_id: 'variant_1',
    external_references: {},
    metadata: {},
    reserved_count: 0,
    incoming_count: 0,
    purchasable_count: 10,
    variant_name: 'T-Shirt',
    variant_sku: 'TS-001',
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
    stock_location_name: 'Main',
    product_id: 'prod_1',
    options_text: 'Red / M',
    thumbnail_url: null,
    allocated_count: 0,
    available_count: 10,
    ...overrides,
  }
}

describe('mergeStockLevelUpdate', () => {
  it('applies updated counts while keeping the expanded variant from the list fetch', () => {
    const previous = stockLevel({
      count_on_hand: 10,
      variant: {
        id: 'variant_1',
        product_id: 'prod_1',
        product_name: 'T-Shirt',
        sku: 'TS-001',
        options_text: 'Red / M',
      } as StockLevel['variant'],
    })
    const updated = stockLevel({
      count_on_hand: 25,
      backorderable: true,
      updated_at: '2026-01-02T00:00:00Z',
    })

    const merged = mergeStockLevelUpdate(previous, updated)

    expect(merged.count_on_hand).toBe(25)
    expect(merged.backorderable).toBe(true)
    expect(merged.variant).toEqual(previous.variant)
    expect(merged.product_id).toBe('prod_1')
  })

  it('prefers an expanded variant on the update response when present', () => {
    const previous = stockLevel({
      variant: {
        id: 'variant_1',
        product_id: 'prod_1',
        product_name: 'Old name',
      } as StockLevel['variant'],
    })
    const refreshedVariant = {
      id: 'variant_1',
      product_id: 'prod_1',
      product_name: 'New name',
    } as StockLevel['variant']
    const updated = stockLevel({ variant: refreshedVariant })

    expect(mergeStockLevelUpdate(previous, updated).variant).toEqual(refreshedVariant)
  })
})
