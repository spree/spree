import type { StockMovement } from '@spree/admin-sdk'
import { adminClient, useResourceKey, useStore } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  Pagination,
  RelativeTime,
  StatusBadge,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@spree/dashboard-ui'
import { useQuery } from '@tanstack/react-query'
import { Link } from '@tanstack/react-router'
import { HistoryIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

/**
 * What the history is about. Movement history is only ever read about
 * something — a SKU ("why is this 47?"), a warehouse ("what changed in
 * Brooklyn this week?"), or one document ("what did this trip actually
 * move?"). The legacy admin's undifferentiated firehose answered none of them
 * (docs/plans/6.0-inventory-operations.md), so every surface takes exactly
 * one subject.
 */
type StockHistoryScope = {
  /** One SKU's history, or a product's across all of its variants. */
  variantIds?: string[]
  stockLocationId?: string | null
  /** One trip's own rows — its departure and its arrivals, across both ends. */
  stockTransferId?: string | null
  /** One order's own rows: every delivery counted in against it. */
  purchaseOrderId?: string | null
}

/** Why the on-hand number is what it is, as a card on a document's page. */
export function StockHistoryCard({ title, ...scope }: StockHistoryScope & { title?: string }) {
  const { t } = useTranslation()

  return (
    <Card>
      <CardHeader>
        <CardTitle>{title ?? t('admin.stock_history.title')}</CardTitle>
      </CardHeader>
      <CardContent className="p-0">
        <StockHistoryTable {...scope} />
      </CardContent>
    </Card>
  )
}

/**
 * The same history behind a button, for a page that is a form: a product's
 * ledger is read, never edited, so it sits beside the inventory card rather
 * than between two things the merchant is about to save.
 */
export function StockHistoryDialog(scope: StockHistoryScope) {
  const { t } = useTranslation()
  const [open, setOpen] = useState(false)

  return (
    <>
      <Button type="button" variant="outline" size="sm" onClick={() => setOpen(true)}>
        <HistoryIcon />
        {t('admin.stock_history.title')}
      </Button>
      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="sm:max-w-[min(1100px,calc(100%-2rem))]">
          <DialogHeader>
            <DialogTitle>{t('admin.stock_history.title')}</DialogTitle>
            <DialogDescription>{t('admin.stock_history.description')}</DialogDescription>
          </DialogHeader>
          <DialogBody className="p-0">{open && <StockHistoryTable {...scope} />}</DialogBody>
        </DialogContent>
      </Dialog>
    </>
  )
}

function StockHistoryTable({
  variantIds,
  stockLocationId,
  stockTransferId,
  purchaseOrderId,
}: StockHistoryScope) {
  const { t } = useTranslation()
  const [page, setPage] = useState(1)

  // A movement carries no variant or warehouse of its own — it hangs off a
  // stock level, which is the (variant, warehouse) pair — so those two filters
  // reach through it. A document's id sits on the movement directly, which is
  // what lets a transfer show both ends of its own trip: the departure is
  // recorded against the source's shelf and the arrivals against the
  // destination's, so a warehouse scope could only ever show half of it.
  const scope = [
    variantIds?.length
      ? { key: variantIds.join(','), stock_level_variant_id_in: variantIds }
      : null,
    stockTransferId ? { key: stockTransferId, stock_transfer_id_eq: stockTransferId } : null,
    purchaseOrderId ? { key: purchaseOrderId, purchase_order_id_eq: purchaseOrderId } : null,
    stockLocationId
      ? { key: stockLocationId, stock_level_stock_location_id_eq: stockLocationId }
      : null,
  ].find((candidate) => candidate !== null)

  const { data, isLoading } = useQuery({
    queryKey: useResourceKey('stock-movements', `${scope?.key ?? ''}-${page}`),
    queryFn: () => {
      const { key: _key, ...filter } = scope ?? {}
      return adminClient.stockMovements.list({ page, limit: 10, ...filter })
    },
    enabled: !!scope,
  })

  const movements = data?.data ?? []
  const paginated = (data?.meta?.pages ?? 1) > 1

  if (isLoading) {
    return <p className="p-3 text-muted-foreground text-sm">{t('admin.common.loading')}</p>
  }
  if (movements.length === 0) {
    return <p className="p-3 text-muted-foreground text-sm">{t('admin.stock_history.empty')}</p>
  }

  return (
    <>
      {/* The pagination bar brings its own top rule and padding, so it takes
          the bottom curve when it is there — and the last row takes it when
          the history fits on one page. */}
      <Table scrollX roundedBottom={!paginated}>
        <TableHeader>
          <TableRow>
            <TableHead>{t('admin.stock_history.columns.date')}</TableHead>
            <TableHead>{t('admin.stock_history.columns.product')}</TableHead>
            <TableHead>{t('admin.stock_history.columns.where')}</TableHead>
            <TableHead>{t('admin.stock_history.columns.change')}</TableHead>
            <TableHead>{t('admin.stock_history.columns.kind')}</TableHead>
            <TableHead>{t('admin.stock_history.columns.cause')}</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {movements.map((movement) => (
            <TableRow key={movement.id}>
              <TableCell className="whitespace-nowrap text-muted-foreground text-sm">
                <RelativeTime iso={movement.created_at} />
              </TableCell>
              <TableCell>
                <div className="min-w-0">
                  <div className="truncate font-medium">{movement.variant_name ?? '—'}</div>
                  {movement.variant_sku && (
                    <div className="text-muted-foreground text-xs">{movement.variant_sku}</div>
                  )}
                </div>
              </TableCell>
              <TableCell className="whitespace-nowrap text-sm">
                {movement.stock_location_name ?? '—'}
              </TableCell>
              <TableCell className="font-medium tabular-nums">
                <QuantityChange movement={movement} />
              </TableCell>
              <TableCell>
                {movement.kind ? (
                  <StatusBadge
                    status={movement.kind}
                    label={t(`admin.stock_history.kinds.${movement.kind}`)}
                  />
                ) : (
                  '—'
                )}
              </TableCell>
              <TableCell className="whitespace-nowrap text-sm">
                <MovementCause movement={movement} />
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
      {paginated && data?.meta && <Pagination meta={data.meta} onPageChange={setPage} />}
    </>
  )
}

/**
 * The direction lives in the kind, not the sign: `shipped` rows are stored
 * positive and read as a departure, while `adjusted` keeps whatever sign the
 * merchant's correction had.
 */
function QuantityChange({ movement }: { movement: StockMovement }) {
  // Only `shipped` needs flipping: it is stored positive and means a
  // departure. `adjusted` already carries the sign the merchant entered, and
  // every other kind is an addition.
  const signed = movement.kind === 'shipped' ? -Math.abs(movement.quantity) : movement.quantity

  return (
    <span className={signed < 0 ? 'text-danger' : 'text-success'}>
      {signed > 0 ? `+${signed}` : signed}
    </span>
  )
}

/**
 * What caused the change, named the way the merchant knows it — "Stock
 * transfer T1001" — and pointing at the document where one has a page. A
 * return or an exchange lives on its order's page, so its row goes there.
 */
function MovementCause({ movement }: { movement: StockMovement }) {
  const { t } = useTranslation()
  const { storeId } = useStore()

  const orderHref = movement.order_id ? `/${storeId}/orders/${movement.order_id}` : null
  const cause = movement.purchase_order_id
    ? {
        label: t('admin.stock_history.causes.purchase_order'),
        number: movement.purchase_order_number,
        href: `/${storeId}/purchase-orders/${movement.purchase_order_id}`,
      }
    : movement.stock_transfer_id
      ? {
          label: t('admin.stock_history.causes.stock_transfer'),
          number: movement.stock_transfer_number,
          href: `/${storeId}/transfers/${movement.stock_transfer_id}`,
        }
      : movement.return_id
        ? {
            label: t('admin.stock_history.causes.return'),
            number: movement.return_number,
            href: orderHref,
          }
        : movement.exchange_id
          ? {
              label: t('admin.stock_history.causes.exchange'),
              number: movement.exchange_number,
              href: orderHref,
            }
          : movement.fulfillment_id
            ? {
                label: t('admin.stock_history.causes.fulfillment'),
                number: movement.order_number,
                href: orderHref,
              }
            : movement.order_id
              ? {
                  label: t('admin.stock_history.causes.order'),
                  number: movement.order_number,
                  href: orderHref,
                }
              : null

  if (!cause) {
    return (
      <span className="text-muted-foreground">
        {movement.reason ?? t('admin.stock_history.causes.manual')}
      </span>
    )
  }

  const text = cause.number ? `${cause.label} ${cause.number}` : cause.label
  if (!cause.href) return <span>{text}</span>

  return (
    <Link to={cause.href} className="font-medium hover:underline">
      {text}
    </Link>
  )
}
