import { describe, expect, it } from 'vitest'
import {
  buildOrderItemsPayload,
  type OrderEditItemValues,
  orderEditItemSchema,
  projectedLineTotal,
  projectedPrice,
  projectedSubtotal,
} from './order'

function row(overrides: Partial<OrderEditItemValues>): OrderEditItemValues {
  return {
    variant_id: 'variant_1',
    quantity: 1,
    removed: false,
    added: false,
    saved_quantity: 1,
    fulfilled_quantity: 0,
    price: '10.0',
    saved_price: '10.0',
    price_source: null,
    catalog_price: '10.0',
    revert_price: false,
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

  it('sends an edited price stamped onto the row', () => {
    expect(buildOrderItemsPayload([row({ price: '7.20', saved_price: '10.0' })])).toEqual([
      { variant_id: 'variant_1', quantity: 1, price: '7.20' },
    ])
  })

  it('omits an untouched price so the server never mistakes it for a negotiation', () => {
    expect(buildOrderItemsPayload([row({ quantity: 5, saved_quantity: 2 })])).toEqual([
      { variant_id: 'variant_1', quantity: 5 },
    ])
  })

  it('sends the explicit null for a staged revert', () => {
    expect(buildOrderItemsPayload([row({ revert_price: true, price_source: 'manual' })])).toEqual([
      { variant_id: 'variant_1', quantity: 1, price: null },
    ])
  })

  it('lets a revert win over a price typed in the same session', () => {
    expect(
      buildOrderItemsPayload([
        row({ revert_price: true, price: '7.20', saved_price: '10.0', price_source: 'manual' }),
      ]),
    ).toEqual([{ variant_id: 'variant_1', quantity: 1, price: null }])
  })
})

describe('orderEditItemSchema price format', () => {
  it('accepts a plain decimal', () => {
    expect(orderEditItemSchema.safeParse(row({ price: '7.20' })).success).toBe(true)
  })

  it('rejects a non-numeric price', () => {
    const result = orderEditItemSchema.safeParse(row({ price: '12,50' }))

    expect(result.success).toBe(false)
    expect(result.error?.issues[0]?.path).toEqual(['price'])
  })

  it('rejects a negative price', () => {
    expect(orderEditItemSchema.safeParse(row({ price: '-3' })).success).toBe(false)
  })

  // Refusing the form over a price that is never sent would block the obvious
  // way out of having typed it: deleting the row.
  it('ignores an invalid price on a row being removed', () => {
    expect(orderEditItemSchema.safeParse(row({ price: '12,50', removed: true })).success).toBe(true)
  })

  it('ignores an invalid price on a row being reverted to catalog price', () => {
    const result = orderEditItemSchema.safeParse(
      row({ price: '12,50', revert_price: true, catalog_price: '25.0' }),
    )

    expect(result.success).toBe(true)
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

// The order editor previews staged edits before they are saved, so these
// projections are what the merchant reads while deciding whether to Save.
describe('projections', () => {
  it('projects a typed price against the current quantity', () => {
    const item = row({ price: '7.20', saved_price: '10.0', quantity: 25 })

    expect(projectedPrice(item)).toBe(7.2)
    expect(projectedLineTotal(item)).toBe(180)
  })

  it('projects a staged revert at the catalog price, not the negotiated one', () => {
    const item = row({
      price: '7.20',
      saved_price: '7.20',
      catalog_price: '25.0',
      price_source: 'manual',
      revert_price: true,
      quantity: 4,
    })

    expect(projectedPrice(item)).toBe(25)
    expect(projectedLineTotal(item)).toBe(100)
  })

  it('gives up rather than guessing when a revert has no catalog price', () => {
    const item = row({ revert_price: true, catalog_price: null })

    expect(projectedPrice(item)).toBeNull()
    expect(projectedLineTotal(item)).toBeNull()
  })

  it('counts a removed row as nothing', () => {
    expect(projectedLineTotal(row({ removed: true, quantity: 3 }))).toBe(0)
  })

  it('sums the rows into a subtotal', () => {
    const items = [
      row({ price: '7.20', quantity: 25 }),
      row({ price: '10.0', quantity: 2 }),
      row({ removed: true, price: '99.0', quantity: 1 }),
    ]

    expect(projectedSubtotal(items)).toBe(200)
  })

  // A partial sum rendered as a total is a wrong number stated confidently.
  it('refuses a subtotal when any row is unprojectable', () => {
    const items = [
      row({ price: '10.0', quantity: 1 }),
      row({ revert_price: true, catalog_price: null }),
    ]

    expect(projectedSubtotal(items)).toBeNull()
  })

  it('treats a non-numeric price as unprojectable rather than zero', () => {
    expect(projectedPrice(row({ price: '12,50' }))).toBeNull()
  })
})
