import type { Refund } from '@spree/admin-sdk'

/** An order's refunds by the payment each went back to, oldest first. */
export function refundsByPayment(refunds: Refund[] | undefined): Map<string, Refund[]> {
  const byPayment = new Map<string, Refund[]>()
  const oldestFirst = [...(refunds ?? [])].sort((a, b) => a.created_at.localeCompare(b.created_at))

  for (const refund of oldestFirst) {
    if (!refund.payment_id) continue
    const forPayment = byPayment.get(refund.payment_id)
    if (forPayment) forPayment.push(refund)
    else byPayment.set(refund.payment_id, [refund])
  }

  return byPayment
}
