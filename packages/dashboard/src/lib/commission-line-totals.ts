import type { CommissionLine } from '@spree/admin-sdk'
import { formatPrice } from '@spree/dashboard-core'

function sumDecimalStrings(values: string[]) {
  return values.reduce((sum, value) => sum + Number.parseFloat(value), 0)
}

export function commissionLineTotals(lines: CommissionLine[], fallbackCurrency: string) {
  const currency = lines[0]?.currency ?? fallbackCurrency
  const amount = sumDecimalStrings(lines.map((line) => line.amount))
  const tax = sumDecimalStrings(lines.map((line) => line.tax_amount))
  const total = sumDecimalStrings(lines.map((line) => line.total))

  const format = (value: number) =>
    formatPrice({
      amount: value.toFixed(2),
      currency,
      display_amount: null,
    })

  return {
    amount,
    tax,
    total,
    displayAmount: format(amount),
    displayTax: format(tax),
    displayTotal: format(total),
  }
}
