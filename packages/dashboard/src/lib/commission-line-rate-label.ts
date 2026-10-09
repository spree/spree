import { type CommissionLine, isDecimalString, type Order } from '@spree/admin-sdk'
import { prorateMoney } from '@spree/dashboard-core'
import i18n, { type TFunction } from 'i18next'
import { formatAmount } from './format-amount'

function snapshottedFixedAmount(line: CommissionLine, order: Order, t: TFunction) {
  if (line.line_item_id) {
    const item = order.items?.find((row) => row.id === line.line_item_id)
    const quantity = item?.quantity ?? 1
    if (quantity <= 0)
      return formatAmount(line.amount, line.currency, i18n.language, t('admin.common.empty_value'))

    if (!isDecimalString(line.amount)) return t('admin.common.empty_value')

    return formatAmount(
      prorateMoney(line.amount, 1, quantity, line.currency),
      line.currency,
      i18n.language,
    )
  }

  return formatAmount(line.amount, line.currency, i18n.language, t('admin.common.empty_value'))
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
