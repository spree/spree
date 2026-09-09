import type { PurchaseOrder, PurchaseOrderItem } from '@spree/admin-sdk'
import { adminClient, Can, PageHeader, Subject, useStore } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  DropdownMenuItem,
  ErrorState,
  RelativeTime,
  ResourceLayout,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
  useConfirm,
} from '@spree/dashboard-ui'
import { PencilIcon, Trash2Icon, XCircleIcon } from '@spree/dashboard-ui/icons'
import { createFileRoute, Link, useNavigate } from '@tanstack/react-router'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { InventoryStatusBadge } from '../../../../../../components/spree/inventory-status-badge'
import { QuantityCell, QuantityHead } from '../../../../../../components/spree/quantity-cell'
import { ResourceDetailSkeleton } from '../../../../../../components/spree/route-pending'
import { StockHistoryCard } from '../../../../../../components/spree/stock-history-card'
import { VariantLink } from '../../../../../../components/spree/variant-link'
import {
  useCancelPurchaseOrder,
  useDeletePurchaseOrder,
  useMarkPurchaseOrderOrdered,
  usePurchaseOrder,
  useReceivePurchaseOrder,
} from '../../../../../../hooks/use-purchase-orders'
import { spreeJsonLinkResolver } from '../../../../../../lib/json-link-resolver'
import { isClosed } from '../../../../../../schemas/inventory-operations'

export const Route = createFileRoute(
  '/_authenticated/$storeId/products/purchase-orders/$purchaseOrderId/',
)({
  component: PurchaseOrderDetailPage,
})

function PurchaseOrderDetailPage() {
  const { t } = useTranslation()
  const { purchaseOrderId } = Route.useParams()
  const { data: purchaseOrder, isLoading, error, refetch } = usePurchaseOrder(purchaseOrderId)

  if (isLoading) {
    return <ResourceDetailSkeleton sidebar />
  }

  // A failed request is not a slow one: without this the screen shows
  // "Loading…" for as long as the merchant is willing to look at it.
  if (error || !purchaseOrder) {
    return (
      <ErrorState
        title={t('admin.purchase_orders.errors.failed_to_load')}
        error={error as Error | undefined}
        onRetry={() => refetch()}
      />
    )
  }

  return (
    <ResourceLayout
      header={<PurchaseOrderHeader purchaseOrder={purchaseOrder} />}
      main={
        <>
          <ItemsCard purchaseOrder={purchaseOrder} />
          <StockHistoryCard
            purchaseOrderId={purchaseOrder.id}
            title={t('admin.purchase_orders.history_title')}
          />
        </>
      }
      sidebar={<SummaryCard purchaseOrder={purchaseOrder} />}
    />
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
        {/* One label-over-value pair per row: the card sits in the narrow
            sidebar column, where a side-by-side grid wraps every value. */}
        <dl className="flex flex-col gap-3 text-sm">
          <dt className="text-muted-foreground">{t('admin.purchase_orders.fields.supplier')}</dt>
          <dd>
            {purchaseOrder.supplier_id ? (
              <Link
                to="/$storeId/products/suppliers"
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
          <dd>
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
          <dd className="tabular-nums">
            {t('admin.purchase_orders.units_summary', {
              received: purchaseOrder.quantity_received_total,
              ordered: purchaseOrder.quantity_ordered_total,
            })}
          </dd>

          <dt className="text-muted-foreground">{t('admin.purchase_orders.fields.subtotal')}</dt>
          <dd className="tabular-nums">{purchaseOrder.display_subtotal}</dd>

          <dt className="text-muted-foreground">{t('admin.purchase_orders.fields.expected_at')}</dt>
          <dd>{purchaseOrder.expected_at ?? '—'}</dd>

          {purchaseOrder.reference && (
            <>
              <dt className="text-muted-foreground">
                {t('admin.purchase_orders.fields.reference')}
              </dt>
              <dd>{purchaseOrder.reference}</dd>
            </>
          )}

          {purchaseOrder.notes && (
            <>
              <dt className="text-muted-foreground">{t('admin.purchase_orders.fields.notes')}</dt>
              <dd className="whitespace-pre-line">{purchaseOrder.notes}</dd>
            </>
          )}

          <dt className="text-muted-foreground">{t('admin.purchase_orders.fields.ordered_at')}</dt>
          <dd>
            {purchaseOrder.ordered_at ? <RelativeTime iso={purchaseOrder.ordered_at} /> : '—'}
          </dd>

          <dt className="text-muted-foreground">{t('admin.purchase_orders.fields.received_at')}</dt>
          <dd>
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
      <CardContent className="flex flex-col p-0">
        {items.length === 0 ? (
          <p className="p-3 text-muted-foreground text-sm">
            {t('admin.purchase_orders.items_empty')}
          </p>
        ) : (
          /* Nothing sits below the table on a draft, so its last row carries
             the card's own curve; on a receivable order the footer does. */
          <Table scrollX roundedBottom={!receivable}>
            <TableHeader>
              <TableRow>
                <TableHead>{t('admin.inventory_lines.columns.variant')}</TableHead>
                <TableHead className="text-right">
                  {t('admin.purchase_orders.columns.quantity_ordered')}
                </TableHead>
                <QuantityHead>{t('admin.purchase_orders.columns.quantity_received')}</QuantityHead>
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
        )}

        {receivable && items.length > 0 && (
          <div className="flex items-center justify-between p-3">
            <p className="text-muted-foreground text-sm tabular-nums">
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
      {/* Never below what is already on the shelf: taking units back off is a
          correction, not a receive. */}
      <QuantityCell
        editable={receivable}
        value={receivable ? count : item.quantity_received}
        min={item.quantity_received}
        max={item.quantity_ordered}
        label={t('admin.purchase_orders.columns.quantity_received')}
        onChange={onCount}
      />
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
  const { storeId } = useStore()
  const confirm = useConfirm()
  const navigate = useNavigate()
  const markOrdered = useMarkPurchaseOrderOrdered(purchaseOrder.id)
  const cancelOrder = useCancelPurchaseOrder(purchaseOrder.id)
  const deleteOrder = useDeletePurchaseOrder()

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

  // Back to the list on success: the record this page describes is gone, and
  // re-fetching it would 404.
  async function handleDelete() {
    const ok = await confirm({
      title: t('admin.purchase_orders.delete_confirm.title'),
      message: t('admin.purchase_orders.delete_confirm.message', {
        number: purchaseOrder.number,
      }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return

    const deleted = await deleteOrder
      .mutateAsync(purchaseOrder.id)
      .then(() => true)
      .catch(() => false)
    if (!deleted) return

    navigate({ to: '/$storeId/products/purchase-orders', params: { storeId } })
  }

  return (
    <PageHeader
      title={purchaseOrder.number}
      backTo="products/purchase-orders"
      badges={<InventoryStatusBadge status={purchaseOrder.status} resource="purchase_orders" />}
      actions={
        open && (
          <Can I="update" a={Subject.PurchaseOrder}>
            {/* A draft is the only order whose lines are still a plan rather
                than a commitment to a supplier, which `editable` reports. */}
            {purchaseOrder.editable && (
              <Button variant="outline" asChild>
                <Link
                  to="/$storeId/products/purchase-orders/$purchaseOrderId/edit"
                  params={{ storeId, purchaseOrderId: purchaseOrder.id }}
                >
                  <PencilIcon className="size-4" />
                  {t('admin.actions.edit')}
                </Link>
              </Button>
            )}
            {purchaseOrder.status === 'draft' && (
              <Button
                type="button"
                onClick={handleOrder}
                disabled={markOrdered.isPending || (purchaseOrder.items_count ?? 0) === 0}
              >
                {t('admin.purchase_orders.actions.mark_ordered')}
              </Button>
            )}
          </Can>
        )
      }
      destructiveItems={
        open && (
          <>
            {/* A draft is not yet a commitment to anyone, so it can simply be
                thrown away — the same action the list offers. Once placed, the
                order is a matter of record with the supplier and calling it
                off is the only way out. */}
            {purchaseOrder.status === 'draft' && (
              <Can I="destroy" a={Subject.PurchaseOrder}>
                <DropdownMenuItem
                  variant="destructive"
                  onClick={handleDelete}
                  disabled={deleteOrder.isPending}
                >
                  <Trash2Icon className="size-4" />
                  {t('admin.actions.delete')}
                </DropdownMenuItem>
              </Can>
            )}
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
          </>
        )
      }
      resource={{ id: purchaseOrder.id, number: purchaseOrder.number }}
      jsonPreview={{
        title: purchaseOrder.number,
        fetch: () => adminClient.purchaseOrders.get(purchaseOrder.id, { expand: ['items'] }),
        endpoint: `/api/v3/admin/purchase_orders/${purchaseOrder.id}`,
        resolveLink: spreeJsonLinkResolver(storeId),
      }}
    />
  )
}
