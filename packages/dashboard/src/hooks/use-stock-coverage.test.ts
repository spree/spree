import { describe, expect, it } from 'vitest'
import { type CoverageStockLevel, computeStockCoverage } from './use-stock-coverage'

function stockLevel(overrides: Partial<CoverageStockLevel>): CoverageStockLevel {
  return {
    stock_location_id: 'sloc_1',
    variant_id: 'variant_1',
    available_count: 0,
    backorderable: false,
    ...overrides,
  }
}

describe('computeStockCoverage', () => {
  it('covers a location holding enough of every demanded variant', () => {
    const coverage = computeStockCoverage(
      [
        stockLevel({ variant_id: 'variant_1', available_count: 5 }),
        stockLevel({ variant_id: 'variant_2', available_count: 2 }),
      ],
      [
        { variantId: 'variant_1', quantity: 3 },
        { variantId: 'variant_2', quantity: 2 },
      ],
    )

    expect(coverage.get('sloc_1')).toBe(true)
  })

  it('does not cover a location short on one variant', () => {
    const coverage = computeStockCoverage(
      [
        stockLevel({ variant_id: 'variant_1', available_count: 5 }),
        stockLevel({ variant_id: 'variant_2', available_count: 1 }),
      ],
      [
        { variantId: 'variant_1', quantity: 1 },
        { variantId: 'variant_2', quantity: 2 },
      ],
    )

    expect(coverage.get('sloc_1')).toBe(false)
  })

  // Backorderable is exactly how a merchant ships from a warehouse awaiting a
  // transfer, so an empty shelf still counts as covered.
  it('treats a backorderable row as unlimited', () => {
    const coverage = computeStockCoverage(
      [stockLevel({ available_count: 0, backorderable: true })],
      [{ variantId: 'variant_1', quantity: 99 }],
    )

    expect(coverage.get('sloc_1')).toBe(true)
  })

  it('does not cover a location missing a variant entirely', () => {
    const coverage = computeStockCoverage(
      [stockLevel({ stock_location_id: 'sloc_1', variant_id: 'variant_1', available_count: 5 })],
      [
        { variantId: 'variant_1', quantity: 1 },
        { variantId: 'variant_2', quantity: 1 },
      ],
    )

    expect(coverage.get('sloc_1')).toBe(false)
  })

  it('keeps locations independent of one another', () => {
    const coverage = computeStockCoverage(
      [
        stockLevel({ stock_location_id: 'sloc_1', available_count: 10 }),
        stockLevel({ stock_location_id: 'sloc_2', available_count: 0 }),
      ],
      [{ variantId: 'variant_1', quantity: 4 }],
    )

    expect(coverage.get('sloc_1')).toBe(true)
    expect(coverage.get('sloc_2')).toBe(false)
  })
})
