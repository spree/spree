import { compareMoney, isDecimalString, isZeroMoney, sumMoney } from '@spree/admin-sdk'
import { formatMoney } from './formatters'
import { prorateMoney } from './money'

/** True when a received return is owed nothing, so completing it moves no money. */
export function returnOwesNothing(refundableTotal: string): boolean {
  return isZeroMoney(refundableTotal)
}

export type ReturnRefundFigures = {
  status: string
  refund_total: string
  refunded_total: string
}

/**
 * What a return's card reports: what it is owed until money goes back, then
 * what actually went back — which a merchant keeping a restocking fee makes
 * less than it was owed, so that case also names the full amount. Money that
 * went back counts even before the return is marked refunded: a refund that
 * succeeded on one payment and was declined on the next leaves it received.
 *
 * A return carries no currency of its own, so the caller passes its order's.
 * Without one the amounts come back as the API wrote them.
 */
export function returnRefundSummary(
  returnRecord: ReturnRefundFigures,
  currency?: string,
  locale?: string,
):
  | { kind: 'owed'; amount: string }
  | { kind: 'refunded'; amount: string }
  | { kind: 'refunded_short'; amount: string; total: string } {
  const format = (amount: string) => (currency ? formatMoney(amount, currency, locale) : amount)

  if (returnRecord.status !== 'refunded' && isZeroMoney(returnRecord.refunded_total)) {
    return { kind: 'owed', amount: format(returnRecord.refund_total) }
  }

  if (compareMoney(returnRecord.refunded_total || '0', returnRecord.refund_total || '0') < 0) {
    return {
      kind: 'refunded_short',
      amount: format(returnRecord.refunded_total),
      total: format(returnRecord.refund_total),
    }
  }

  return { kind: 'refunded', amount: format(returnRecord.refunded_total) }
}

/**
 * What the customer paid, tax included, for `quantity` units of a line — the
 * refund a claim offers until the merchant types their own. Blank when the
 * line's amounts are unknown.
 */
export function paidForUnits(
  line: {
    quantity: number
    discounted_amount?: string | null
    additional_tax_total?: string | null
  },
  quantity: number,
  currency: string,
): string {
  if (quantity <= 0 || line.quantity <= 0 || !isDecimalString(line.discounted_amount)) return ''

  const tax = isDecimalString(line.additional_tax_total) ? line.additional_tax_total : '0'
  const paid = sumMoney([line.discounted_amount, tax])
  return prorateMoney(paid, quantity, line.quantity, currency)
}
