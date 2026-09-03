import type { CommissionLine, Order } from '@spree/admin-sdk'
import { currencyParts } from '@spree/dashboard-core'
import {
  Card,
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
  const name = line.commission_rate?.name ?? t('admin.orders.detail.commission_lines.rate_unknown')

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

export function CommissionLinesCard({ order }: { order: Order }) {
  const { t, i18n } = useTranslation()
  const { data, isSuccess } = useOrderCommissionLines(order.id, {
    enabled: !!order.completed_at,
  })

  if (!order.completed_at) return null

  const lines = data?.data ?? []
  if (!isSuccess || lines.length === 0) return null

  return (
    <Card>
      <CardHeader>
        <CardTitle>
          <PercentIcon className="size-4" />
          {t('admin.orders.detail.commission_lines.title')}
        </CardTitle>
      </CardHeader>

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
        </TableBody>
      </Table>
    </Card>
  )
}
