import { describe, expect, it } from 'vitest'
import { commissionLinesParams } from './use-order'

describe('commission line params', () => {
  it('names the ransack predicate at the top level', () => {
    expect(commissionLinesParams('or_123')).toMatchObject({ order_id_eq: 'or_123' })
  })

  // Nesting them under `q` serialises to `q[q]=[object Object]`: Ransack drops
  // the predicate, and the order page shows every commission line in the
  // store — other sellers' orders included.
  it('nests nothing the SDK would stringify into a predicate', () => {
    const nested = Object.entries(commissionLinesParams('or_123')).filter(
      ([, value]) => typeof value === 'object' && !Array.isArray(value),
    )

    expect(nested).toEqual([])
  })
})
