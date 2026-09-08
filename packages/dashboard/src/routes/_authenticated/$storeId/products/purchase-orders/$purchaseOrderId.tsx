import type { PurchaseOrder, PurchaseOrderItem } from '@spree/admin-sdk'
import { Can, PageHeader, Subject, useStore } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  DropdownMenuItem,
  Input,
  RelativeTime,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
  useConfirm,
} from '@spree/dashboard-ui'
import { XCircleIcon } from '@spree/dashboard-ui/icons'
import { createFileRoute, Link } from '@tanstack/react-router'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { InventoryStatusBadge } from '../../../../../components/spree/inventory-status-badge'
import { StockHistoryCard } from '../../../../../components/spree/stock-history-card'
import { VariantLink } from '../../../../../components/spree/variant-link'
import {
  useCancelPurchaseOrder,
  useMarkPurchaseOrderOrdered,
  usePurchaseOrder,
  useReceivePurchaseOrder,
} from '../../../../../hooks/use-purchase-orders'
import { isClosed } from '../../../../../schemas/inventory-operations'

export const Route = createFileRoute(
  '/_authenticated/$storeId/products/purchase-orders/$purchaseOrderId',
)({
  component: PurchaseOrderDetailPage,
})

function PurchaseOrderDetailPage() {
  const { t } = useTranslation()
  const { purchaseOrderId } = Route.useParams()
  const { data: purchaseOrder, isLoading } = usePurchaseOrder(purchaseOrderId)

  if (isLoading || !purchaseOrder) {
    return <div className="p-4 text-sm text-muted-foreground">{t('admin.common.loading')}</div>
  }

  return (
    <div className="mx-auto flex w-full max-w-4xl flex-col gap-4 p-4">
      <PurchaseOrderHeader purchaseOrder={purchaseOrder} />

      <SummaryCard purchaseOrder={purchaseOrder} />
      <ItemsCard purchaseOrder={purchaseOrder} />

      <StockHistoryCard
        stockLocationId={purchaseOrder.destination_location_id}
        title={t('admin.purchase_orders.history_title')}
      />
    </div>
  )
}

function SummaryCard({ purchaseOrder }: { purchaseOrder: PurchaseOrder }) {
  const { t } = useTranslation()
  const { storeId } = useStore()

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.purchase_orders.details_title')}</CardTitle>
      </CardHeader>
      <CardContent>
        <dl className="grid grid-cols-3 gap-y-2 text-sm">
          <dt className="text-muted-foreground">{t('admin.purchase_orders.fields.supplier')}</dt>
          <dd className="col-span-2">
            {purchaseOrder.supplier_id ? (
              <Link
                to="/$storeId/settings/suppliers"
                params={{ storeId }}
                search={{ edit: purchaseOrder.supplier_id }}
                className="text-foreground hover:underline"
              >
                {purchaseOrder.supplier?.name ?? purchaseOrder.supplier_id}
              </Link>
            ) : (
              '—'
            )}
          </dd>

          <dt className="text-muted-foreground">{t('admin.purchase_orders.fields.destination')}</dt>
          <dd className="col-span-2">
            {purchaseOrder.destination_location_id ? (
              <Link
                to="/$storeId/settings/stock-locations"
                params={{ storeId }}
                search={{ edit: purchaseOrder.destination_location_id }}
                className="text-foreground hover:underline"
              >
                {purchaseOrder.destination_location?.name ?? purchaseOrder.destination_location_id}
              </Link>
            ) : (
              '—'
            )}
          </dd>

          <dt className="text-muted-foreground">{t('admin.purchase_orders.fields.units')}</dt>
          <dd className="col-span-2 tabular-nums">
            {t('admin.purchase_orders.units_summary', {
              received: purchaseOrder.quantity_received_total,
              ordered: purchaseOrder.quantity_ordered_total,
            })}
          </dd>

          <dt className="text-muted-foreground">{t('admin.purchase_orders.fields.subtotal')}</dt>
          <dd className="col-span-2 tabular-nums">{purchaseOrder.display_subtotal}</dd>

          <dt className="text-muted-foreground">{t('admin.purchase_orders.fields.expected_at')}</dt>
          <dd className="col-span-2">{purchaseOrder.expected_at ?? '—'}</dd>

          {purchaseOrder.reference && (
            <>
              <dt className="text-muted-foreground">
                {t('admin.purchase_orders.fields.reference')}
              </dt>
              <dd className="col-span-2">{purchaseOrder.reference}</dd>
            </>
          )}

          {purchaseOrder.notes && (
            <>
              <dt className="text-muted-foreground">{t('admin.purchase_orders.fields.notes')}</dt>
              <dd className="col-span-2 whitespace-pre-line">{purchaseOrder.notes}</dd>
            </>
          )}

          <dt className="text-muted-foreground">{t('admin.purchase_orders.fields.ordered_at')}</dt>
          <dd className="col-span-2">
            {purchaseOrder.ordered_at ? <RelativeTime iso={purchaseOrder.ordered_at} /> : '—'}
          </dd>

          <dt className="text-muted-foreground">{t('admin.purchase_orders.fields.received_at')}</dt>
          <dd className="col-span-2">
            {purchaseOrder.received_at ? <RelativeTime iso={purchaseOrder.received_at} /> : '—'}
          </dd>
        </dl>
      </CardContent>
    </Card>
  )
}

/**
 * The lines, and — once the order has been placed — the receive screen.
 *
 * `quantity_received` is the running total for the line, so a second delivery
 * tops it up rather than starting over — and the inputs show what has actually
 * arrived, not what was ordered.
 */
function ItemsCard({ purchaseOrder }: { purchaseOrder: PurchaseOrder }) {
  const { t } = useTranslation()
  const items = purchaseOrder.items ?? []
  const receiveMutation = useReceivePurchaseOrder(purchaseOrder.id)
  const receivable =
    purchaseOrder.status === 'ordered' || purchaseOrder.status === 'partially_received'

  const [counts, setCounts] = useState<Record<string, number>>(() =>
    Object.fromEntries(items.map((item) => [item.id, item.quantity_received])),
  )

  const totalCounted = items.reduce((sum, item) => sum + (counts[item.id] ?? 0), 0)

  async function handleReceive() {
    await receiveMutation
      .mutateAsync({
        items: items.map((item) => ({
          id: item.id,
          quantity_received: counts[item.id] ?? item.quantity_received,
        })),
      })
      .catch(() => undefined)
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>
          {receivable
            ? t('admin.purchase_orders.receive_title')
            : t('admin.purchase_orders.items_title')}
        </CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-4">
        {items.length === 0 ? (
          <p className="text-sm text-muted-foreground">{t('admin.purchase_orders.items_empty')}</p>
        ) : (
          <div className="overflow-x-auto">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t('admin.inventory_lines.columns.variant')}</TableHead>
                  <TableHead className="text-right">
                    {t('admin.purchase_orders.columns.quantity_ordered')}
                  </TableHead>
                  <TableHead className="text-right">
                    {t('admin.purchase_orders.columns.quantity_received')}
                  </TableHead>
                  <TableHead className="text-right">
                    {t('admin.inventory_lines.columns.unit_cost')}
                  </TableHead>
                  <TableHead className="text-right">
                    {t('admin.purchase_orders.columns.line_total')}
                  </TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {items.map((item) => (
                  <ItemRow
                    key={item.id}
                    item={item}
                    receivable={receivable}
                    count={counts[item.id] ?? item.quantity_received}
                    onCount={(value) => setCounts((prev) => ({ ...prev, [item.id]: value }))}
                  />
                ))}
              </TableBody>
            </Table>
          </div>
        )}

        {receivable && items.length > 0 && (
          <div className="flex items-center justify-between">
            <p className="text-sm text-muted-foreground tabular-nums">
              {t('admin.purchase_orders.receive_running_total', {
                counted: totalCounted,
                ordered: purchaseOrder.quantity_ordered_total,
              })}
            </p>
            <Can I="update" a={Subject.PurchaseOrder}>
              <Button type="button" onClick={handleReceive} disabled={receiveMutation.isPending}>
                {receiveMutation.isPending
                  ? t('admin.actions.saving')
                  : t('admin.purchase_orders.actions.receive')}
              </Button>
            </Can>
          </div>
        )}
      </CardContent>
    </Card>
  )
}

function ItemRow({
  item,
  receivable,
  count,
  onCount,
}: {
  item: PurchaseOrderItem
  receivable: boolean
  count: number
  onCount: (value: number) => void
}) {
  const { t } = useTranslation()

  return (
    <TableRow>
      <TableCell>
        <VariantLink
          productId={item.product_id}
          name={item.variant_name}
          sku={item.variant_sku}
          thumbnailUrl={item.thumbnail_url}
        />
      </TableCell>
      <TableCell className="text-right tabular-nums">{item.quantity_ordered}</TableCell>
      <TableCell className="text-right">
        {receivable ? (
          <Input
            type="number"
            // Never below what is already on the shelf: taking units back off
            // is a correction, not a receive.
            min={item.quantity_received}
            max={item.quantity_ordered}
            value={count}
            onChange={(event) => onCount(Number(event.target.value))}
            className="ml-auto w-20 text-right tabular-nums"
            aria-label={t('admin.purchase_orders.columns.quantity_received')}
          />
        ) : (
          <span className="tabular-nums">{item.quantity_received}</span>
        )}
      </TableCell>
      <TableCell className="text-right tabular-nums">{item.display_unit_cost}</TableCell>
      <TableCell className="text-right tabular-nums">{item.display_total_cost}</TableCell>
    </TableRow>
  )
}

/**
 * Title, status, and the transitions — the same layout an order's header uses:
 * placing the order is the button, calling it off is in the menu.
 */
function PurchaseOrderHeader({ purchaseOrder }: { purchaseOrder: PurchaseOrder }) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const markOrdered = useMarkPurchaseOrderOrdered(purchaseOrder.id)
  const cancelOrder = useCancelPurchaseOrder(purchaseOrder.id)

  const open = !isClosed(purchaseOrder.status)

  async function handleOrder() {
    const ok = await confirm({
      title: t('admin.purchase_orders.order_confirm.title'),
      message: t('admin.purchase_orders.order_confirm.message', {
        supplier: purchaseOrder.supplier?.name ?? '',
      }),
      confirmLabel: t('admin.purchase_orders.actions.mark_ordered'),
    })
    if (!ok) return
    await markOrdered.mutateAsync().catch(() => undefined)
  }

  async function handleCancel() {
    const ok = await confirm({
      title: t('admin.purchase_orders.cancel_confirm.title'),
      message: t('admin.purchase_orders.cancel_confirm.message'),
      variant: 'destructive',
      confirmLabel: t('admin.purchase_orders.actions.cancel_order'),
    })
    if (!ok) return
    await cancelOrder.mutateAsync({}).catch(() => undefined)
  }

  return (
    <PageHeader
      title={purchaseOrder.number}
      backTo="products/purchase-orders"
      badges={<InventoryStatusBadge status={purchaseOrder.status} resource="purchase_orders" />}
      actions={
        open &&
        purchaseOrder.status === 'draft' && (
          <Can I="update" a={Subject.PurchaseOrder}>
            <Button
              type="button"
              onClick={handleOrder}
              disabled={markOrdered.isPending || (purchaseOrder.items_count ?? 0) === 0}
            >
              {t('admin.purchase_orders.actions.mark_ordered')}
            </Button>
          </Can>
        )
      }
      destructiveItems={
        open && (
          <Can I="update" a={Subject.PurchaseOrder}>
            <DropdownMenuItem
              variant="destructive"
              onClick={handleCancel}
              disabled={cancelOrder.isPending}
            >
              <XCircleIcon className="size-4" />
              {t('admin.purchase_orders.actions.cancel_order')}
            </DropdownMenuItem>
          </Can>
        )
      }
      resource={{ id: purchaseOrder.id, number: purchaseOrder.number }}
    />
  )
}
