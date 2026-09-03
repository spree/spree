import type { CommissionLine, Order } from '@spree/admin-sdk'
import { currencyParts, formatPrice } from '@spree/dashboard-core'
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@spree/dashboard-ui'
import { PercentIcon } from '@spree/dashboard-ui/icons'
import { useTranslation } from 'react-i18next'
import { useOrderCommissionLines } from '../../../hooks/use-order'

function commissionSubjectLabel(line: CommissionLine, order: Order, t: (key: string) => string) {
  if (line.line_item_id) {
    const item = order.items?.find((row) => row.id === line.line_item_id)
    return item?.name ?? t('admin.orders.detail.commission_lines.line_item_fallback')
  }

  if (line.fulfillment_id) {
    return t('admin.orders.detail.commission_lines.delivery')
  }

  return t('admin.orders.detail.commission_lines.subject_fallback')
}

function commissionRateLabel(
  line: CommissionLine,
  t: (key: string, options?: Record<string, unknown>) => string,
  locale: string,
) {
  const name = line.commission_rate_name ?? t('admin.orders.detail.commission_lines.rate_unknown')

  if (line.kind === 'percentage') {
    return t('admin.orders.detail.commission_lines.rate_named_percentage', {
      name,
      rate: line.rate,
    })
  }

  const { symbol } = currencyParts(line.currency, locale)
  return t('admin.orders.detail.commission_lines.rate_named_fixed', {
    name,
    amount: `${symbol}${line.rate}`,
  })
}

function sumDecimalStrings(values: string[]) {
  return values.reduce((sum, value) => sum + Number.parseFloat(value), 0)
}

export function CommissionLinesCard({ order }: { order: Order }) {
  const { t, i18n } = useTranslation()
  const { data, isPending, isError, isSuccess } = useOrderCommissionLines(order.id, {
    enabled: !!order.completed_at,
  })

  if (!order.completed_at) return null

  const lines = data?.data ?? []
  if (isSuccess && lines.length === 0) return null

  const emptyMessage = isPending
    ? t('admin.common.loading')
    : isError
      ? t('admin.errors.failed_to_load')
      : t('admin.orders.detail.commission_lines.empty')

  const totalAmount = sumDecimalStrings(lines.map((line) => line.amount))
  const totalTax = sumDecimalStrings(lines.map((line) => line.tax_amount))
  const totalCommission = sumDecimalStrings(lines.map((line) => line.total))
  const currency = lines[0]?.currency ?? order.currency
  const formatTotal = (amount: number) =>
    formatPrice({
      amount: amount.toFixed(2),
      currency,
      display_amount: null,
    })

  return (
    <Card>
      <CardHeader>
        <CardTitle>
          <PercentIcon className="size-4" />
          {t('admin.orders.detail.commission_lines.title')}
        </CardTitle>
      </CardHeader>

      {lines.length === 0 ? (
        <CardContent>
          <p className="text-sm text-muted-foreground">{emptyMessage}</p>
        </CardContent>
      ) : (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>{t('admin.orders.detail.commission_lines.column_subject')}</TableHead>
              <TableHead>{t('admin.orders.detail.commission_lines.column_rate')}</TableHead>
              <TableHead className="text-right">
                {t('admin.orders.detail.commission_lines.column_fee')}
              </TableHead>
              <TableHead className="text-right">
                {t('admin.orders.detail.commission_lines.column_tax')}
              </TableHead>
              <TableHead className="text-right">
                {t('admin.orders.detail.commission_lines.column_total')}
              </TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {lines.map((line) => (
              <TableRow key={line.id}>
                <TableCell>{commissionSubjectLabel(line, order, t)}</TableCell>
                <TableCell className="text-muted-foreground">
                  {commissionRateLabel(line, t, i18n.language)}
                </TableCell>
                <TableCell className="text-right tabular-nums">{line.display_amount}</TableCell>
                <TableCell className="text-right tabular-nums">{line.display_tax_amount}</TableCell>
                <TableCell className="text-right tabular-nums">{line.display_total}</TableCell>
              </TableRow>
            ))}
            {lines.length > 1 && (
              <TableRow className="font-medium">
                <TableCell colSpan={2}>{t('admin.orders.detail.commission_lines.total')}</TableCell>
                <TableCell className="text-right tabular-nums">
                  {formatTotal(totalAmount)}
                </TableCell>
                <TableCell className="text-right tabular-nums">{formatTotal(totalTax)}</TableCell>
                <TableCell className="text-right tabular-nums">
                  {formatTotal(totalCommission)}
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      )}
    </Card>
  )
}
