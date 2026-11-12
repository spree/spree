import { describe, expect, it } from 'vitest'
import { productFormSchema } from './product-schema'

describe('productFormSchema status', () => {
  it('accepts a status an extension added, so the form still saves', () => {
    expect(productFormSchema.shape.status.safeParse('pending_compliance').success).toBe(true)
  })
})
