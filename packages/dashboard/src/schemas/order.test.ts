import { describe, expect, it } from 'vitest'
import { buildOrderItemsPayload, type OrderEditItemValues, orderEditItemSchema } from './order'

function row(overrides: Partial<OrderEditItemValues>): OrderEditItemValues {
  return {
    variant_id: 'variant_1',
    quantity: 1,
    removed: false,
    added: false,
    saved_quantity: 1,
    fulfilled_quantity: 0,
    name: 'Shirt',
    options_text: '',
    thumbnail_url: null,
    display_price: '$10.00',
    display_total: '$10.00',
    ...overrides,
  }
}

describe('buildOrderItemsPayload', () => {
  it('omits rows the merchant did not touch', () => {
    expect(buildOrderItemsPayload([row({ quantity: 2, saved_quantity: 2 })])).toEqual([])
  })

  it('sends the new quantity for a changed row', () => {
    expect(buildOrderItemsPayload([row({ quantity: 5, saved_quantity: 2 })])).toEqual([
      { variant_id: 'variant_1', quantity: 5 },
    ])
  })

  it('sends quantity 0 for a removed row', () => {
    expect(
      buildOrderItemsPayload([row({ removed: true, quantity: 3, saved_quantity: 3 })]),
    ).toEqual([{ variant_id: 'variant_1', quantity: 0 }])
  })

  it('sends the quantity for a staged addition', () => {
    expect(buildOrderItemsPayload([row({ added: true, quantity: 4, saved_quantity: 0 })])).toEqual([
      { variant_id: 'variant_1', quantity: 4 },
    ])
  })

  it('drops an addition that was staged and then removed', () => {
    expect(
      buildOrderItemsPayload([row({ added: true, removed: true, quantity: 4, saved_quantity: 0 })]),
    ).toEqual([])
  })

  it('ignores a quantity edit made on a row that is also removed', () => {
    expect(
      buildOrderItemsPayload([row({ removed: true, quantity: 9, saved_quantity: 3 })]),
    ).toEqual([{ variant_id: 'variant_1', quantity: 0 }])
  })
})

// Shipped units are physical fact — the schema refuses edits that pretend
// they can come back.
describe('orderEditItemSchema fulfilled clamp', () => {
  it('rejects a quantity below the fulfilled count', () => {
    const result = orderEditItemSchema.safeParse(
      row({ quantity: 1, saved_quantity: 3, fulfilled_quantity: 2 }),
    )

    expect(result.success).toBe(false)
    expect(result.error?.issues[0]?.path).toEqual(['quantity'])
  })

  it('rejects removing a row with fulfilled units', () => {
    const result = orderEditItemSchema.safeParse(
      row({ removed: true, quantity: 3, saved_quantity: 3, fulfilled_quantity: 3 }),
    )

    expect(result.success).toBe(false)
  })

  it('accepts trimming down to exactly the fulfilled count', () => {
    const result = orderEditItemSchema.safeParse(
      row({ quantity: 2, saved_quantity: 3, fulfilled_quantity: 2 }),
    )

    expect(result.success).toBe(true)
  })

  it('accepts removing a row with nothing fulfilled', () => {
    const result = orderEditItemSchema.safeParse(
      row({ removed: true, quantity: 3, saved_quantity: 3 }),
    )

    expect(result.success).toBe(true)
  })
})
