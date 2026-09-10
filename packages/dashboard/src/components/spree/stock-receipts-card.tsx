import type { PaginatedResponse, StockReceipt } from '@spree/admin-sdk'
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  RelativeTime,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@spree/dashboard-ui'
import { useQuery } from '@tanstack/react-query'
import { useTranslation } from 'react-i18next'
import { VariantLink } from './variant-link'

/**
 * The deliveries booked against a purchase order or a transfer, newest first,
 * each with the lines it counted. The document's running totals say where it
 * stands; this says how it got there.
 */
export function StockReceiptsCard({
  queryKey,
  fetch,
}: {
  queryKey: readonly unknown[]
  fetch: () => Promise<PaginatedResponse<StockReceipt>>
}) {
  const { t } = useTranslation()
  const { data, isError } = useQuery({ queryKey, queryFn: fetch })
  const receipts = data?.data ?? []

  return (
    <Card>
      <CardHeader>
        <CardTitle>
          {t('admin.stock_receipts.title')}
          {receipts.length > 0 && (
            <span className="ml-2 font-normal text-muted-foreground text-sm">
              {receipts.length}
            </span>
          )}
        </CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col p-0">
        {/* A failed request is not an empty list: saying "no deliveries" over an
            error would tell the merchant something false about their stock. */}
        {isError ? (
          <p className="p-4 text-destructive text-sm">{t('admin.stock_receipts.load_failed')}</p>
        ) : receipts.length === 0 ? (
          <p className="p-4 text-muted-foreground text-sm">{t('admin.stock_receipts.empty')}</p>
        ) : (
          receipts.map((receipt) => (
            <div key={receipt.id} className="border-t first:border-t-0">
              <div className="flex flex-wrap items-baseline gap-x-3 gap-y-1 px-4 py-3 text-sm">
                <span className="font-medium tabular-nums">{receipt.number}</span>
                <RelativeTime iso={receipt.received_at} className="text-muted-foreground" />
                {receipt.reference && (
                  <span className="text-muted-foreground">{receipt.reference}</span>
                )}
                <span className="ml-auto text-muted-foreground tabular-nums">
                  {t('admin.stock_receipts.summary', {
                    accepted: receipt.quantity_accepted_total,
                    rejected: receipt.quantity_rejected_total,
                  })}
                </span>
              </div>
              {receipt.items && receipt.items.length > 0 && (
                <Table scrollX>
                  <TableHeader>
                    <TableRow>
                      <TableHead>{t('admin.inventory_lines.columns.variant')}</TableHead>
                      <TableHead className="text-right">
                        {t('admin.stock_receipts.columns.accepted')}
                      </TableHead>
                      <TableHead className="text-right">
                        {t('admin.stock_receipts.columns.rejected')}
                      </TableHead>
                      <TableHead>{t('admin.stock_receipts.columns.reason')}</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {receipt.items.map((item) => (
                      <TableRow key={item.id}>
                        <TableCell>
                          <VariantLink
                            name={item.variant_name}
                            sku={item.variant_sku}
                            thumbnailUrl={item.thumbnail_url}
                          />
                        </TableCell>
                        <TableCell className="text-right tabular-nums">
                          {item.quantity_accepted}
                        </TableCell>
                        <TableCell className="text-right tabular-nums">
                          {item.quantity_rejected}
                        </TableCell>
                        <TableCell>
                          {item.rejection_reason
                            ? t(`admin.stock_receipts.rejection_reasons.${item.rejection_reason}`, {
                                defaultValue: item.rejection_reason,
                              })
                            : '—'}
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              )}
              {receipt.notes && (
                <p className="px-4 pb-3 text-muted-foreground text-sm">{receipt.notes}</p>
              )}
            </div>
          ))
        )}
      </CardContent>
    </Card>
  )
}
