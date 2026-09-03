import type { CommissionLine, Order } from '@spree/admin-sdk'
import { formatPrice } from '@spree/dashboard-core'
import type { TFunction } from 'i18next'

function snapshottedFixedAmount(line: CommissionLine, order: Order, t: TFunction) {
  if (line.line_item_id) {
    const item = order.items?.find((row) => row.id === line.line_item_id)
    const quantity = item?.quantity ?? 1
    if (quantity <= 0) return line.display_amount || t('admin.common.empty_value')

    const perUnit = Number.parseFloat(line.amount) / quantity
    if (!Number.isFinite(perUnit)) return t('admin.common.empty_value')

    return formatPrice({
      amount: perUnit.toFixed(2),
      currency: line.currency,
      display_amount: null,
    })
  }

  return line.display_amount || t('admin.common.empty_value')
}

export function commissionRateLabel(line: CommissionLine, order: Order, t: TFunction) {
  const name = line.commission_rate?.name ?? t('admin.orders.detail.commission_lines.rate_unknown')

  if (line.kind === 'percentage') {
    return t('admin.orders.detail.commission_lines.rate_named_percentage', {
      name,
      rate: line.rate,
    })
  }

  return t('admin.orders.detail.commission_lines.rate_named_fixed', {
    name,
    amount: snapshottedFixedAmount(line, order, t),
  })
}
