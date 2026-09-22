import type { PurchaseOrder, PurchaseOrderItem } from '@spree/admin-sdk'
import {
  adminClient,
  Can,
  PageHeader,
  Subject,
  useResourceKey,
  useStore,
} from '@spree/dashboard-core'
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
import {
  PackageCheckIcon,
  PencilIcon,
  Trash2Icon,
  Undo2Icon,
  XCircleIcon,
} from '@spree/dashboard-ui/icons'
import { createFileRoute, Link, useNavigate } from '@tanstack/react-router'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { CloseShortDialog } from '../../../../../components/spree/close-short-dialog'
import { InventoryStatusBadge } from '../../../../../components/spree/inventory-status-badge'
import { ReceiveDeliveryCard } from '../../../../../components/spree/receive-delivery-card'
import { ResourceDetailSkeleton } from '../../../../../components/spree/route-pending'
import { StockHistoryCard } from '../../../../../components/spree/stock-history-card'
import { StockReceiptsCard } from '../../../../../components/spree/stock-receipts-card'
import { VariantLink } from '../../../../../components/spree/variant-link'
import {
  useCancelPurchaseOrder,
  useClosePurchaseOrder,
  useCreatePurchaseOrderReceipt,
  useDeletePurchaseOrder,
  useMarkPurchaseOrderDraft,
  useMarkPurchaseOrderOrdered,
  usePurchaseOrder,
} from '../../../../../hooks/use-purchase-orders'
import { spreeJsonLinkResolver } from '../../../../../lib/json-link-resolver'
import { isClosed } from '../../../../../schemas/inventory-operations'

export const Route = createFileRoute('/_authenticated/$storeId/purchase-orders/$purchaseOrderId/')({
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
          {(purchaseOrder.status === 'ordered' ||
            purchaseOrder.status === 'partially_received') && (
            <ReceiveCard purchaseOrder={purchaseOrder} />
          )}
          <ItemsCard purchaseOrder={purchaseOrder} />
          <ReceiptsCard purchaseOrder={purchaseOrder} />
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
                to="/$storeId/suppliers"
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

          {purchaseOrder.cancel_by && (
            <>
              <dt className="text-muted-foreground">
                {t('admin.purchase_orders.fields.cancel_by')}
              </dt>
              <dd>{purchaseOrder.cancel_by}</dd>
            </>
          )}

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

          {purchaseOrder.closed_short && (
            <>
              <dt className="text-muted-foreground">
                {t('admin.purchase_orders.fields.closed_short')}
              </dt>
              <dd>
                <RelativeTime iso={purchaseOrder.closed_short_at as string} />
              </dd>
              {purchaseOrder.close_reason && (
                <>
                  <dt className="text-muted-foreground">
                    {t('admin.purchase_orders.fields.close_reason')}
                  </dt>
                  <dd className="whitespace-pre-line">{purchaseOrder.close_reason}</dd>
                </>
              )}
            </>
          )}
        </dl>
      </CardContent>
    </Card>
  )
}

/** What a delivery is counted against, in the receive card's vocabulary. */
function receivableLines(purchaseOrder: PurchaseOrder) {
  return (purchaseOrder.items ?? []).map((item) => ({
    id: item.id,
    product_id: item.product_id,
    variant_name: item.variant_name,
    variant_sku: item.variant_sku,
    thumbnail_url: item.thumbnail_url,
    quantity_expected: item.quantity_ordered,
    quantity_received: item.quantity_received,
    quantity_rejected: item.quantity_rejected,
    outstanding: item.outstanding,
  }))
}

function ReceiveCard({ purchaseOrder }: { purchaseOrder: PurchaseOrder }) {
  const { t } = useTranslation()
  const receive = useCreatePurchaseOrderReceipt(purchaseOrder.id)

  return (
    <ReceiveDeliveryCard
      lines={receivableLines(purchaseOrder)}
      expectedLabel={t('admin.purchase_orders.columns.quantity_ordered')}
      subject={Subject.PurchaseOrder}
      pending={receive.isPending}
      onReceive={(params) => receive.mutateAsync(params)}
    />
  )
}

function ReceiptsCard({ purchaseOrder }: { purchaseOrder: PurchaseOrder }) {
  const queryKey = useResourceKey('purchase-orders', purchaseOrder.id, 'stock-receipts')
  return (
    <StockReceiptsCard
      queryKey={queryKey}
      fetch={() =>
        adminClient.purchaseOrders.stockReceipts.list(purchaseOrder.id, { expand: ['items'] })
      }
    />
  )
}

/**
 * The lines as they stand: what was ordered, what each delivery has brought
 * and refused so far, and what the merchant agreed to pay.
 */
function ItemsCard({ purchaseOrder }: { purchaseOrder: PurchaseOrder }) {
  const { t } = useTranslation()
  const items = purchaseOrder.items ?? []
  const anyOver = items.some((item) => item.quantity_over > 0)

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.purchase_orders.items_title')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col p-0">
        {items.length === 0 ? (
          <p className="p-3 text-muted-foreground text-sm">
            {t('admin.purchase_orders.items_empty')}
          </p>
        ) : (
          <Table scrollX roundedBottom>
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
                  {t('admin.purchase_orders.columns.quantity_rejected')}
                </TableHead>
                {anyOver && (
                  <TableHead className="text-right">
                    {t('admin.purchase_orders.columns.quantity_over')}
                  </TableHead>
                )}
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
                <ItemRow key={item.id} item={item} showOver={anyOver} />
              ))}
            </TableBody>
          </Table>
        )}
      </CardContent>
    </Card>
  )
}

function ItemRow({ item, showOver }: { item: PurchaseOrderItem; showOver: boolean }) {
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
      <TableCell className="text-right tabular-nums">{item.quantity_received}</TableCell>
      <TableCell className="text-right tabular-nums">{item.quantity_rejected}</TableCell>
      {showOver && <TableCell className="text-right tabular-nums">{item.quantity_over}</TableCell>}
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
  const markDraft = useMarkPurchaseOrderDraft(purchaseOrder.id)
  const closeOrder = useClosePurchaseOrder(purchaseOrder.id)
  const [closeOpen, setCloseOpen] = useState(false)

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

    navigate({ to: '/$storeId/purchase-orders', params: { storeId } })
  }

  return (
    <>
      {closeOpen && (
        <CloseShortDialog
          title={t('admin.purchase_orders.close_confirm.title')}
          description={t('admin.purchase_orders.close_confirm.message', {
            outstanding:
              purchaseOrder.quantity_ordered_total - purchaseOrder.quantity_received_total,
          })}
          pending={closeOrder.isPending}
          onConfirm={(reason) => closeOrder.mutateAsync({ reason })}
          onClose={() => setCloseOpen(false)}
        />
      )}
      <PageHeader
        title={purchaseOrder.number}
        backTo="purchase-orders"
        badges={<InventoryStatusBadge status={purchaseOrder.status} resource="purchase_orders" />}
        actions={
          open && (
            <Can I="update" a={Subject.PurchaseOrder}>
              {/* A draft is the only order whose lines are still a plan rather
                than a commitment to a supplier, which `editable` reports. */}
              {purchaseOrder.editable && (
                <Button variant="outline" asChild>
                  <Link
                    to="/$storeId/purchase-orders/$purchaseOrderId/edit"
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
              {/* Only until something arrives: the server refuses it after the
                first delivery, and so does the screen. */}
              {purchaseOrder.status === 'ordered' && (
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => markDraft.mutateAsync().catch(() => undefined)}
                  disabled={markDraft.isPending}
                >
                  <Undo2Icon className="size-4" />
                  {t('admin.purchase_orders.actions.mark_draft')}
                </Button>
              )}
            </Can>
          )
        }
        dropdownItems={
          purchaseOrder.status === 'partially_received' && (
            <Can I="update" a={Subject.PurchaseOrder}>
              <DropdownMenuItem onClick={() => setCloseOpen(true)} disabled={closeOrder.isPending}>
                <PackageCheckIcon className="size-4" />
                {t('admin.purchase_orders.actions.close_short')}
              </DropdownMenuItem>
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
    </>
  )
}
