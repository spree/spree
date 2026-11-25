import { describe, expect, it } from 'vitest'
import { releasesPreviousCustomerBalance } from './order-customer-form'

const draft = {
  completed_at: null,
  customer_id: 'cus_first',
  gift_card: null,
  payments: [{ source_type: 'store_credit' as const, status: 'checkout' }],
}

describe('releasesPreviousCustomerBalance', () => {
  it("gives a draft's store credit back when it moves to another customer or a guest", () => {
    expect(releasesPreviousCustomerBalance(draft, 'cus_second')).toBe(true)
    expect(releasesPreviousCustomerBalance(draft, null)).toBe(true)
  })

  it('keeps it when the customer stays, the order is placed, or nothing valid was paid by credit', () => {
    expect(releasesPreviousCustomerBalance(draft, 'cus_first')).toBe(false)
    expect(
      releasesPreviousCustomerBalance(
        { ...draft, completed_at: '2026-01-01T00:00:00Z' },
        'cus_second',
      ),
    ).toBe(false)
    expect(
      releasesPreviousCustomerBalance(
        { ...draft, payments: [{ source_type: 'store_credit', status: 'void' }] },
        'cus_second',
      ),
    ).toBe(false)
    expect(
      releasesPreviousCustomerBalance(
        { ...draft, payments: [{ source_type: 'credit_card', status: 'checkout' }] },
        'cus_second',
      ),
    ).toBe(false)
  })

  it('gives back only a gift card issued to someone other than the new customer', () => {
    const named = { ...draft, gift_card: { customer_id: 'cus_first' } }
    expect(releasesPreviousCustomerBalance(named, 'cus_second')).toBe(true)
    expect(
      releasesPreviousCustomerBalance(
        { ...draft, gift_card: { customer_id: 'cus_second' } },
        'cus_second',
      ),
    ).toBe(false)
    expect(
      releasesPreviousCustomerBalance({ ...draft, gift_card: { customer_id: null } }, 'cus_second'),
    ).toBe(false)
  })
})
