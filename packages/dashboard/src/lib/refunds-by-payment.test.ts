import type { Refund } from '@spree/admin-sdk'
import { describe, expect, it } from 'vitest'
import { refundsByPayment } from './refunds-by-payment'

function refund(id: string, paymentId: string | null, createdAt: string): Refund {
  return { id, payment_id: paymentId, created_at: createdAt, amount: '10.00' } as Refund
}

describe('refundsByPayment', () => {
  it('lists each refund under the payment it went back to, oldest first', () => {
    const grouped = refundsByPayment([
      refund('ref_2', 'py_1', '2026-11-12T10:00:00Z'),
      refund('ref_3', 'py_2', '2026-11-11T10:00:00Z'),
      refund('ref_1', 'py_1', '2026-11-11T09:00:00Z'),
    ])

    expect(grouped.get('py_1')?.map((row) => row.id)).toEqual(['ref_1', 'ref_2'])
    expect(grouped.get('py_2')?.map((row) => row.id)).toEqual(['ref_3'])
  })

  it('has nothing for an order that was never refunded', () => {
    expect(refundsByPayment(undefined).size).toBe(0)
  })

  it('skips a refund with no payment', () => {
    expect(refundsByPayment([refund('ref_1', null, '2026-11-11T09:00:00Z')]).size).toBe(0)
  })
})
