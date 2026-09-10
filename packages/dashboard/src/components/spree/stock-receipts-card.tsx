import type { PaginatedResponse, StockReceipt } from '@spree/admin-sdk'
import {
  Badge,
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
import { PackageCheckIcon } from '@spree/dashboard-ui/icons'
import { useQuery } from '@tanstack/react-query'
import { useTranslation } from 'react-i18next'
import { VariantLink } from './variant-link'

/**
 * The deliveries booked against a purchase order or a transfer, each as a
 * nested card inside one container — the way an order's fulfillments read.
 * The document's running totals say where it stands; this says how it got
 * there.
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
    <Card variant="container">
      <CardHeader>
        <CardTitle>
          <PackageCheckIcon className="size-4" />
          {t('admin.stock_receipts.title')}
          {receipts.length > 0 && <Badge variant="outline">{receipts.length}</Badge>}
        </CardTitle>
      </CardHeader>
      {/* A failed request is not an empty list: saying "no deliveries" over an
          error would tell the merchant something false about their stock. */}
      {isError ? (
        <CardContent>
          <p className="py-8 text-center text-destructive">
            {t('admin.stock_receipts.load_failed')}
          </p>
        </CardContent>
      ) : receipts.length === 0 ? (
        <CardContent>
          <p className="py-8 text-center text-muted-foreground">
            {t('admin.stock_receipts.empty')}
          </p>
        </CardContent>
      ) : (
        <CardContent className="flex flex-col gap-4">
          {receipts.map((receipt) => (
            <StockReceiptPanel key={receipt.id} receipt={receipt} />
          ))}
        </CardContent>
      )}
    </Card>
  )
}

/** One delivery: when it came, under which note, and what it counted. */
function StockReceiptPanel({ receipt }: { receipt: StockReceipt }) {
  const { t } = useTranslation()
  const items = receipt.items ?? []

  return (
    <Card variant="nested">
      <CardHeader>
        <CardTitle className="min-w-0 font-normal text-sm">
          <span className="font-medium tabular-nums">{receipt.number}</span>
          <span className="text-muted-foreground text-xs">
            <RelativeTime iso={receipt.received_at} />
          </span>
          {receipt.reference && (
            <span className="truncate text-muted-foreground text-xs">{receipt.reference}</span>
          )}
        </CardTitle>
      </CardHeader>

      <CardContent className="flex items-center justify-between border-b border-border-subtle py-3 text-sm">
        <span className="text-muted-foreground">
          {t('admin.stock_receipts.summary', {
            accepted: receipt.quantity_accepted_total,
            rejected: receipt.quantity_rejected_total,
          })}
        </span>
        {receipt.notes && <span className="truncate text-muted-foreground">{receipt.notes}</span>}
      </CardContent>

      {items.length > 0 && (
        <Table scrollX roundedBottom>
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
            {items.map((item) => (
              <TableRow key={item.id}>
                <TableCell>
                  <VariantLink
                    name={item.variant_name}
                    sku={item.variant_sku}
                    thumbnailUrl={item.thumbnail_url}
                  />
                </TableCell>
                <TableCell className="text-right tabular-nums">{item.quantity_accepted}</TableCell>
                <TableCell className="text-right tabular-nums">{item.quantity_rejected}</TableCell>
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
    </Card>
  )
}
