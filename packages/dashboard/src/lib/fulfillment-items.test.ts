import { describe, expect, it } from 'vitest'
import {
  fulfilledQuantities,
  fulfillmentItemRows,
  type GroupableFulfillment,
  type GroupableLineItem,
  unfulfilledItemRows,
} from './fulfillment-items'

function lineItem(overrides: Partial<GroupableLineItem> = {}): GroupableLineItem {
  return {
    id: 'li_1',
    name: 'Shirt',
    options_text: 'Blue / M',
    quantity: 2,
    thumbnail_url: 'https://example.test/shirt.jpg',
    display_price: '$10.00',
    ...overrides,
  }
}

function fulfillment(overrides: Partial<GroupableFulfillment> = {}): GroupableFulfillment {
  return {
    status: 'pending',
    fulfillment_items: [],
    ...overrides,
  }
}

describe('fulfillmentItemRows', () => {
  it('joins a fulfillment item to its line item for the image and price', () => {
    const rows = fulfillmentItemRows(
      fulfillment({
        fulfillment_items: [{ line_item_id: 'li_1', variant_id: 'variant_1', quantity: 1 }],
      }),
      [lineItem()],
    )

    expect(rows).toEqual([
      {
        key: 'li_1',
        lineItem: expect.objectContaining({ id: 'li_1' }),
        name: 'Shirt',
        optionsText: 'Blue / M',
        thumbnailUrl: 'https://example.test/shirt.jpg',
        displayPrice: '$10.00',
        quantity: 1,
      },
    ])
  })

  it('merges several fulfillment items descending from one line item', () => {
    const rows = fulfillmentItemRows(
      fulfillment({
        fulfillment_items: [
          { line_item_id: 'li_1', quantity: 1 },
          { line_item_id: 'li_1', quantity: 2 },
        ],
      }),
      [lineItem({ quantity: 3 })],
    )

    expect(rows).toHaveLength(1)
    expect(rows[0].quantity).toBe(3)
  })

  it('falls back to the fulfillment item copy when the line item is missing', () => {
    const rows = fulfillmentItemRows(
      fulfillment({
        fulfillment_items: [
          { line_item_id: 'li_gone', name: 'Removed item', options_text: 'Red', quantity: 1 },
        ],
      }),
      [],
    )

    expect(rows[0]).toMatchObject({
      name: 'Removed item',
      optionsText: 'Red',
      thumbnailUrl: null,
      displayPrice: null,
    })
  })

  it('keys an item with no line item by its variant so it still renders', () => {
    const rows = fulfillmentItemRows(
      fulfillment({
        fulfillment_items: [{ variant_id: 'variant_9', name: 'Loose unit', quantity: 1 }],
      }),
      [],
    )

    expect(rows).toHaveLength(1)
    expect(rows[0].key).toBe('variant_9')
  })
})

describe('unfulfilledItemRows', () => {
  it('reports the quantity no fulfillment claims', () => {
    const rows = unfulfilledItemRows(
      [lineItem({ quantity: 5 })],
      [fulfillment({ fulfillment_items: [{ line_item_id: 'li_1', quantity: 2 }] })],
    )

    expect(rows).toHaveLength(1)
    expect(rows[0].quantity).toBe(3)
  })

  it('sums claims across several fulfillments', () => {
    const rows = unfulfilledItemRows(
      [lineItem({ quantity: 4 })],
      [
        fulfillment({ fulfillment_items: [{ line_item_id: 'li_1', quantity: 1 }] }),
        fulfillment({
          status: 'shipped',
          fulfillment_items: [{ line_item_id: 'li_1', quantity: 2 }],
        }),
      ],
    )

    expect(rows[0].quantity).toBe(1)
  })

  it('returns nothing when the fulfillments account for every unit', () => {
    const rows = unfulfilledItemRows(
      [lineItem({ quantity: 2 })],
      [fulfillment({ fulfillment_items: [{ line_item_id: 'li_1', quantity: 2 }] })],
    )

    expect(rows).toEqual([])
  })

  it('never reports a negative remainder', () => {
    const rows = unfulfilledItemRows(
      [lineItem({ quantity: 1 })],
      [fulfillment({ fulfillment_items: [{ line_item_id: 'li_1', quantity: 3 }] })],
    )

    expect(rows).toEqual([])
  })

  it('ignores fulfillment items that reference no line item', () => {
    const rows = unfulfilledItemRows(
      [lineItem({ quantity: 2 })],
      [fulfillment({ fulfillment_items: [{ variant_id: 'variant_1', quantity: 2 }] })],
    )

    expect(rows[0].quantity).toBe(2)
  })
})

describe('fulfilledQuantities', () => {
  it('sums units per line item across fulfilled fulfillments', () => {
    const quantities = fulfilledQuantities([
      fulfillment({
        status: 'fulfilled',
        fulfillment_items: [
          { line_item_id: 'li_1', variant_id: 'variant_1', quantity: 1 },
          { line_item_id: 'li_2', variant_id: 'variant_2', quantity: 2 },
        ],
      }),
      fulfillment({
        status: 'fulfilled',
        fulfillment_items: [{ line_item_id: 'li_1', variant_id: 'variant_1', quantity: 2 }],
      }),
    ])

    expect(quantities.get('li_1')).toBe(3)
    expect(quantities.get('li_2')).toBe(2)
  })

  // Canceled fulfillments restock; pending ones have not shipped. Neither
  // pins an edit.
  it('ignores fulfillments that have not shipped', () => {
    const quantities = fulfilledQuantities([
      fulfillment({
        status: 'pending',
        fulfillment_items: [{ line_item_id: 'li_1', variant_id: 'variant_1', quantity: 2 }],
      }),
      fulfillment({
        status: 'canceled',
        fulfillment_items: [{ line_item_id: 'li_1', variant_id: 'variant_1', quantity: 1 }],
      }),
    ])

    expect(quantities.size).toBe(0)
  })

  it('skips fulfillment items that reference no line item', () => {
    const quantities = fulfilledQuantities([
      fulfillment({
        status: 'fulfilled',
        fulfillment_items: [{ line_item_id: null, variant_id: 'variant_1', quantity: 2 }],
      }),
    ])

    expect(quantities.size).toBe(0)
  })
})
