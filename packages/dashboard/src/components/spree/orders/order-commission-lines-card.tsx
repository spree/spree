import type { CommissionLine, Order } from '@spree/admin-sdk'
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
import { commissionRateLabel } from '../../../lib/commission-line-rate-label'

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

export function CommissionLinesCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  const { data, isSuccess, isError, isPending } = useOrderCommissionLines(order.id, {
    enabled: !!order.completed_at,
  })

  if (!order.completed_at) return null

  const lines = data?.data ?? []
  if (isPending) return null
  if (isError) {
    return (
      <Card>
        <CardHeader>
          <CardTitle>
            <PercentIcon className="size-4" />
            {t('admin.orders.detail.commission_lines.title')}
          </CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-muted-foreground">{t('admin.errors.failed_to_load')}</p>
        </CardContent>
      </Card>
    )
  }
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
                {commissionRateLabel(line, order, t)}
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
