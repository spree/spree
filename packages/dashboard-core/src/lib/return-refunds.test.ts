import { describe, expect, it } from 'vitest'
import { paidForUnits, returnOwesNothing, returnRefundSummary } from './return-refunds'

const figures = {
  status: 'received',
  refund_total: '20.00',
  display_refund_total: '$20.00',
  refunded_total: '0.00',
  display_refunded_total: '$0.00',
}

describe('returnRefundSummary', () => {
  it('reports what is owed until money goes back', () => {
    expect(returnRefundSummary(figures)).toEqual({ kind: 'owed', amount: '$20.00' })
  })

  it('names the full amount when less went back than was owed', () => {
    expect(
      returnRefundSummary({
        ...figures,
        status: 'refunded',
        refunded_total: '15.00',
        display_refunded_total: '$15.00',
      }),
    ).toEqual({ kind: 'refunded_short', amount: '$15.00', total: '$20.00' })
  })

  it('reports a full refund', () => {
    expect(
      returnRefundSummary({
        ...figures,
        status: 'refunded',
        refunded_total: '20.00',
        display_refunded_total: '$20.00',
      }),
    ).toEqual({ kind: 'refunded', amount: '$20.00' })
  })
})

describe('returnOwesNothing', () => {
  it('is true only for a zero amount', () => {
    expect(returnOwesNothing('0.00')).toBe(true)
    expect(returnOwesNothing('0.01')).toBe(false)
  })
})

describe('paidForUnits', () => {
  it('shares the paid amount and tax across the chosen units', () => {
    const line = { quantity: 3, discounted_amount: '9.00', additional_tax_total: '1.00' }
    expect(paidForUnits(line, 1, 'USD')).toBe('3.33')
    expect(paidForUnits(line, 3, 'USD')).toBe('10.00')
  })

  it('is blank when nothing is chosen or the amount is unknown', () => {
    expect(paidForUnits({ quantity: 2, discounted_amount: '5.00' }, 0, 'USD')).toBe('')
    expect(paidForUnits({ quantity: 2, discounted_amount: null }, 1, 'USD')).toBe('')
  })
})
