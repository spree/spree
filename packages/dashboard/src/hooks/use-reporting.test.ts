import type { ReportingRow } from '@spree/admin-sdk'
import { describe, expect, it } from 'vitest'
import { entityDimension, rawDimension } from './use-reporting'

// A discount with no coupon code groups under a null `coupon_code`.
const row: ReportingRow = { dimensions: { coupon_code: null }, metrics: {} }

describe('a null dimension value', () => {
  it('reads as an unnamed entity', () => {
    expect(entityDimension(row, 'coupon_code')).toEqual({ id: null, label: '', meta: {} })
  })

  it('reads as an empty raw value', () => {
    expect(rawDimension(row, 'coupon_code')).toBe('')
  })
})
