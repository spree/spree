import type { PaginatedResponse, StockReceipt } from '@spree/admin-sdk'
import {
  Badge,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  RelativeTime,
  Section,
  SectionHeader,
  SectionTitle,
  StatusBadge,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@spree/dashboard-ui'
import { FileTextIcon, PackageCheckIcon } from '@spree/dashboard-ui/icons'
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
    <Section>
      <SectionHeader>
        <SectionTitle>
          <PackageCheckIcon className="size-4" />
          {t('admin.stock_receipts.title')}
          {receipts.length > 0 && <Badge variant="outline">{receipts.length}</Badge>}
        </SectionTitle>
      </SectionHeader>
      {/* A failed request is not an empty list: saying "no deliveries" over an
          error would tell the merchant something false about their stock. */}
      {isError ? (
        <Card>
          <CardContent>
            <p className="py-8 text-center text-destructive">
              {t('admin.stock_receipts.load_failed')}
            </p>
          </CardContent>
        </Card>
      ) : receipts.length === 0 ? (
        <Card>
          <CardContent>
            <p className="py-8 text-center text-muted-foreground">
              {t('admin.stock_receipts.empty')}
            </p>
          </CardContent>
        </Card>
      ) : (
        <div className="flex flex-col gap-4">
          {receipts.map((receipt) => (
            <StockReceiptPanel key={receipt.id} receipt={receipt} />
          ))}
        </div>
      )}
    </Section>
  )
}

/** One delivery: when it came, under which note, and what it counted. */
function StockReceiptPanel({ receipt }: { receipt: StockReceipt }) {
  const { t } = useTranslation()
  const items = receipt.items ?? []

  return (
    // Laid out like a fulfillment: what happened and to which document on
    // the left, when on the right, then the counts on their own row.
    <Card variant="nested" className="px-0">
      <CardHeader className="px-3.5!">
        <CardTitle className="min-w-0 font-normal text-sm">
          <StatusBadge
            status="received"
            tone="success"
            label={t('admin.stock_transfers.statuses.received')}
          />
          <span className="text-muted-foreground tabular-nums">{receipt.number}</span>
          {receipt.reference && (
            <span className="flex min-w-0 items-center gap-1.5 text-muted-foreground text-xs">
              <FileTextIcon className="size-3 shrink-0" />
              <span className="truncate">{receipt.reference}</span>
            </span>
          )}
        </CardTitle>
        <CardAction className="text-muted-foreground text-xs">
          <RelativeTime iso={receipt.received_at} />
        </CardAction>
      </CardHeader>

      <CardContent className="flex items-center justify-between border-b border-border-subtle px-3.5! py-3! text-sm">
        <span className="text-muted-foreground">
          {t('admin.stock_receipts.summary', {
            accepted: receipt.quantity_accepted_total,
            rejected: receipt.quantity_rejected_total,
          })}
        </span>
        {receipt.notes && <span className="truncate text-muted-foreground">{receipt.notes}</span>}
      </CardContent>

      <CardContent className="p-0">
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
                      productId={item.product_id}
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
      </CardContent>
    </Card>
  )
}
