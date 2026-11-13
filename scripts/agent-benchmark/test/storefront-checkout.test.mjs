import assert from 'node:assert/strict'
import { describe, it } from 'node:test'
import { orderMismatch } from '../tasks/storefront-checkout.mjs'

describe('storefront checkout order check', () => {
  const submitted = { variantId: 'variant_abc', quantity: 1, email: 'ada@example.com' }
  const order = (overrides = {}) => ({
    email: 'ada@example.com',
    items: [{ variant_id: 'variant_abc', quantity: 1 }],
    ...overrides,
  })

  it('accepts the order that was submitted', () => {
    assert.equal(orderMismatch(order(), submitted), null)
  })

  it('rejects an order with another email', () => {
    assert.match(orderMismatch(order({ email: 'old@example.com' }), submitted), /email/)
  })

  it('rejects an order with another item, quantity or extra items', () => {
    for (const items of [
      [{ variant_id: 'variant_other', quantity: 1 }],
      [{ variant_id: 'variant_abc', quantity: 2 }],
      [
        { variant_id: 'variant_abc', quantity: 1 },
        { variant_id: 'variant_other', quantity: 1 },
      ],
      [],
    ]) {
      assert.match(orderMismatch(order({ items }), submitted), /items/)
    }
  })
})
