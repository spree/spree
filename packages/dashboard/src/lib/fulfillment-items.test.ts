import { describe, expect, it } from 'vitest'
import {
  fulfillmentItemRows,
  type GroupableFulfillment,
  type GroupableLineItem,
  hasFulfillableUnits,
  isRemovableRow,
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

describe('isRemovableRow', () => {
  it('allows removing a row holding every unit of its line item', () => {
    const [row] = fulfillmentItemRows(
      fulfillment({ fulfillment_items: [{ line_item_id: 'li_1', quantity: 2 }] }),
      [lineItem({ quantity: 2 })],
    )

    expect(isRemovableRow(row)).toBe(true)
  })

  // The other units live in a different group; deleting the line item would
  // silently take those too.
  it('refuses a row holding only part of its line item', () => {
    const [row] = fulfillmentItemRows(
      fulfillment({ fulfillment_items: [{ line_item_id: 'li_1', quantity: 1 }] }),
      [lineItem({ quantity: 3 })],
    )

    expect(isRemovableRow(row)).toBe(false)
  })

  it('refuses a row with no line item behind it', () => {
    const [row] = fulfillmentItemRows(
      fulfillment({ fulfillment_items: [{ variant_id: 'variant_9', quantity: 1 }] }),
      [],
    )

    expect(isRemovableRow(row)).toBe(false)
  })
})

describe('hasFulfillableUnits', () => {
  it('is true while units remain unclaimed', () => {
    expect(hasFulfillableUnits([lineItem({ quantity: 2 })], [])).toBe(true)
  })

  it('is true when a pending fulfillment still holds units to move', () => {
    expect(
      hasFulfillableUnits(
        [lineItem({ quantity: 2 })],
        [fulfillment({ fulfillment_items: [{ line_item_id: 'li_1', quantity: 2 }] })],
      ),
    ).toBe(true)
  })

  it('is false once every unit sits in a shipped fulfillment', () => {
    expect(
      hasFulfillableUnits(
        [lineItem({ quantity: 2 })],
        [
          fulfillment({
            status: 'shipped',
            fulfillment_items: [{ line_item_id: 'li_1', quantity: 2 }],
          }),
        ],
      ),
    ).toBe(false)
  })

  it('is false when a canceled fulfillment holds the units', () => {
    expect(
      hasFulfillableUnits(
        [lineItem({ quantity: 2 })],
        [
          fulfillment({
            status: 'canceled',
            fulfillment_items: [{ line_item_id: 'li_1', quantity: 2 }],
          }),
        ],
      ),
    ).toBe(false)
  })

  it('is false on an order with no items at all', () => {
    expect(hasFulfillableUnits([], [])).toBe(false)
  })

  it('counts a ready_for_pickup fulfillment as movable', () => {
    expect(
      hasFulfillableUnits(
        [lineItem({ quantity: 1 })],
        [
          fulfillment({
            status: 'ready_for_pickup',
            fulfillment_items: [{ line_item_id: 'li_1', quantity: 1 }],
          }),
        ],
      ),
    ).toBe(true)
  })
})
