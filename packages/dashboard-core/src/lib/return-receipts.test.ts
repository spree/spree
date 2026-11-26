import { describe, expect, it } from 'vitest'
import { returnAwaitsGoods, unitsToReceive } from './return-receipts'

describe('unitsToReceive', () => {
  it('counts the units that have not arrived yet', () => {
    expect(unitsToReceive({ quantity: 3, received_quantity: 1 })).toBe(2)
    expect(unitsToReceive({ quantity: 2, received_quantity: 2 })).toBe(0)
    expect(unitsToReceive({ quantity: 2 })).toBe(2)
  })
})

describe('returnAwaitsGoods', () => {
  const lines = (received: number) => [{ quantity: 2, received_quantity: received }]

  it('takes goods once the return is approved', () => {
    expect(returnAwaitsGoods({ status: 'approved', return_line_items: lines(0) })).toBe(true)
  })

  it('keeps taking goods after a partial receipt', () => {
    expect(returnAwaitsGoods({ status: 'received', return_line_items: lines(1) })).toBe(true)
  })

  it('stops once every unit has arrived', () => {
    expect(returnAwaitsGoods({ status: 'received', return_line_items: lines(2) })).toBe(false)
  })

  it('takes nothing before approval or after the return is settled', () => {
    expect(returnAwaitsGoods({ status: 'requested', return_line_items: lines(0) })).toBe(false)
    expect(returnAwaitsGoods({ status: 'refunded', return_line_items: lines(1) })).toBe(false)
    expect(returnAwaitsGoods({ status: 'canceled', return_line_items: lines(0) })).toBe(false)
  })
})
