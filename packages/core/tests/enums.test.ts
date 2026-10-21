import { describe, expect, expectTypeOf, it } from 'vitest'
import { PRODUCT_STATUSES, type ProductStatus, subsetOf } from '../src'

describe('subsetOf', () => {
  it('keeps the picked values and their narrow type', () => {
    const editable = subsetOf(PRODUCT_STATUSES, ['draft', 'active'])

    expect(editable).toEqual(['draft', 'active'])
    expectTypeOf(editable[0]).toEqualTypeOf<'draft' | 'active'>()
  })

  it('answers includes for any status the API returns', () => {
    const status: ProductStatus = 'archived'

    expect(subsetOf(PRODUCT_STATUSES, ['draft']).includes(status)).toBe(false)
  })

  it('rejects a value the list does not hold', () => {
    // @ts-expect-error 'published' is not a built-in product status
    subsetOf(PRODUCT_STATUSES, ['draft', 'published'])
  })
})
