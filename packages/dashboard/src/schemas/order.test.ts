import { describe, expect, it } from 'vitest'
import { buildOrderItemsPayload, type OrderEditItemValues } from './order'

function row(overrides: Partial<OrderEditItemValues>): OrderEditItemValues {
  return {
    variant_id: 'variant_1',
    quantity: 1,
    removed: false,
    added: false,
    saved_quantity: 1,
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
