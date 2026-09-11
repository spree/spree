import type { StockTransfer } from '@spree/admin-sdk'
import {
  adminClient,
  Can,
  PageHeader,
  Subject,
  useResourceKey,
  useStockLocations,
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
import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { CloseShortDialog } from '../../../../../components/spree/close-short-dialog'
import { InventoryStatusBadge } from '../../../../../components/spree/inventory-status-badge'
import { ReceiveDeliveryCard } from '../../../../../components/spree/receive-delivery-card'
import { ResourceDetailSkeleton } from '../../../../../components/spree/route-pending'
import { StockHistoryCard } from '../../../../../components/spree/stock-history-card'
import { StockReceiptsCard } from '../../../../../components/spree/stock-receipts-card'
import { TransferCancelDialog } from '../../../../../components/spree/transfer-cancel-dialog'
import { VariantLink } from '../../../../../components/spree/variant-link'
import {
  useCloseStockTransfer,
  useCreateStockTransferReceipt,
  useDeleteStockTransfer,
  useMarkStockTransferDraft,
  useMarkStockTransferInTransit,
  useMarkStockTransferReady,
  useStockTransfer,
} from '../../../../../hooks/use-stock-transfers'
import { spreeJsonLinkResolver } from '../../../../../lib/json-link-resolver'
import { isClosed, isInFlight } from '../../../../../schemas/inventory-operations'

export const Route = createFileRoute('/_authenticated/$storeId/transfers/$transferId/')({
  component: StockTransferDetailPage,
})

function StockTransferDetailPage() {
  const { t } = useTranslation()
  const { transferId } = Route.useParams()
  const { data: transfer, isLoading, error, refetch } = useStockTransfer(transferId)

  if (isLoading) {
    return <ResourceDetailSkeleton sidebar />
  }

  // A failed request is not a slow one: without this the screen shows
  // "Loading…" for as long as the merchant is willing to look at it.
  if (error || !transfer) {
    return (
      <ErrorState
        title={t('admin.stock_transfers.errors.failed_to_load')}
        error={error as Error | undefined}
        onRetry={() => refetch()}
      />
    )
  }

  return (
    <ResourceLayout
      header={<TransferHeader transfer={transfer} />}
      main={
        <>
          {transfer.status === 'draft' || transfer.status === 'ready_to_ship' ? (
            <PlannedItemsCard transfer={transfer} />
          ) : (
            <>
              {isInFlight(transfer.status) && <ReceiveCard transfer={transfer} />}
              <LinesCard transfer={transfer} />
              <ReceiptsCard transfer={transfer} />
            </>
          )}

          {/* Where the units on this trip came from and went — read on the
              destination warehouse, which is the shelf the merchant is
              reconciling. */}
          <StockHistoryCard
            stockTransferId={transfer.id}
            title={t('admin.stock_transfers.history_title')}
          />
        </>
      }
      sidebar={<SummaryCard transfer={transfer} />}
    />
  )
}

/**
 * A warehouse, linked to the row that configures it. Stock locations have no
 * screen of their own — they are edited from the settings list — so the link
 * opens that list with this one's sheet showing, the way an order links its
 * channel and its market.
 */
function WarehouseLink({
  storeId,
  id,
  name,
}: {
  storeId: string
  id: string | null
  name: string
}) {
  if (!id) return <>{name}</>

  return (
    <Link
      to="/$storeId/settings/stock-locations"
      params={{ storeId }}
      search={{ edit: id }}
      className="text-foreground hover:underline"
    >
      {name}
    </Link>
  )
}

function SummaryCard({ transfer }: { transfer: StockTransfer }) {
  const { t } = useTranslation()
  const { storeId } = useStore()
  const { data: stockLocations } = useStockLocations({ limit: 100 })

  const locationName = useMemo(() => {
    const byId = new Map((stockLocations?.data ?? []).map((l) => [l.id, l.name]))
    return (id: string | null) => (id ? (byId.get(id) ?? id) : '—')
  }, [stockLocations])

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.stock_transfers.details_title')}</CardTitle>
      </CardHeader>
      <CardContent>
        {/* One label-over-value pair per row: the card sits in the narrow
            sidebar column, where a side-by-side grid wraps every value. */}
        <dl className="flex flex-col gap-3 text-sm">
          <dt className="text-muted-foreground">{t('admin.stock_transfers.fields.source')}</dt>
          <dd>
            <WarehouseLink
              storeId={storeId}
              id={transfer.source_location_id}
              name={transfer.source_location?.name ?? locationName(transfer.source_location_id)}
            />
          </dd>

          <dt className="text-muted-foreground">{t('admin.stock_transfers.fields.destination')}</dt>
          <dd>
            <WarehouseLink
              storeId={storeId}
              id={transfer.destination_location_id}
              name={
                transfer.destination_location?.name ??
                locationName(transfer.destination_location_id)
              }
            />
          </dd>

          <dt className="text-muted-foreground">{t('admin.stock_transfers.fields.units')}</dt>
          <dd className="tabular-nums">
            {t('admin.stock_transfers.units_summary', {
              received: transfer.quantity_received_total,
              shipped: transfer.quantity_shipped_total,
            })}
          </dd>

          {transfer.reference && (
            <>
              <dt className="text-muted-foreground">
                {t('admin.stock_transfers.fields.reference')}
              </dt>
              <dd>{transfer.reference}</dd>
            </>
          )}

          {transfer.notes && (
            <>
              <dt className="text-muted-foreground">{t('admin.stock_transfers.fields.notes')}</dt>
              <dd className="whitespace-pre-line">{transfer.notes}</dd>
            </>
          )}

          <dt className="text-muted-foreground">{t('admin.stock_transfers.fields.shipped_at')}</dt>
          <dd>{transfer.shipped_at ? <RelativeTime iso={transfer.shipped_at} /> : '—'}</dd>

          <dt className="text-muted-foreground">{t('admin.stock_transfers.fields.received_at')}</dt>
          <dd>{transfer.received_at ? <RelativeTime iso={transfer.received_at} /> : '—'}</dd>

          {transfer.closed_short && (
            <>
              <dt className="text-muted-foreground">
                {t('admin.stock_transfers.fields.closed_short')}
              </dt>
              <dd>
                <RelativeTime iso={transfer.closed_short_at as string} />
              </dd>
              {transfer.close_reason && (
                <>
                  <dt className="text-muted-foreground">
                    {t('admin.stock_transfers.fields.close_reason')}
                  </dt>
                  <dd className="whitespace-pre-line">{transfer.close_reason}</dd>
                </>
              )}
            </>
          )}
        </dl>
      </CardContent>
    </Card>
  )
}

/** Draft and ready-to-ship: what is going, and nothing about arrival yet. */
function PlannedItemsCard({ transfer }: { transfer: StockTransfer }) {
  const { t } = useTranslation()
  const items = transfer.items ?? []

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.stock_transfers.items_title')}</CardTitle>
      </CardHeader>
      <CardContent className="p-0">
        {items.length === 0 ? (
          <p className="p-3 text-muted-foreground text-sm">
            {t('admin.stock_transfers.items_empty')}
          </p>
        ) : (
          <Table scrollX roundedBottom>
            <TableHeader>
              <TableRow>
                <TableHead>{t('admin.inventory_lines.columns.variant')}</TableHead>
                {/* Nothing has shipped yet on a draft — this is what will. The
                    receive screen keeps `quantity_shipped`, where it is past
                    tense and sits opposite Received. */}
                <TableHead className="text-right">
                  {t('admin.stock_transfers.columns.quantity_to_ship')}
                </TableHead>
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
                  <TableCell className="text-right tabular-nums">{item.quantity_shipped}</TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        )}
      </CardContent>
    </Card>
  )
}

/** What a delivery is counted against, in the receive card's vocabulary. */
function receivableLines(transfer: StockTransfer) {
  return (transfer.items ?? []).map((item) => ({
    id: item.id,
    product_id: item.product_id,
    variant_name: item.variant_name,
    variant_sku: item.variant_sku,
    thumbnail_url: item.thumbnail_url,
    quantity_expected: item.quantity_shipped,
    quantity_received: item.quantity_received,
    quantity_rejected: item.quantity_rejected,
    outstanding: item.outstanding,
  }))
}

function ReceiveCard({ transfer }: { transfer: StockTransfer }) {
  const { t } = useTranslation()
  const receive = useCreateStockTransferReceipt(transfer.id)

  return (
    <ReceiveDeliveryCard
      lines={receivableLines(transfer)}
      expectedLabel={t('admin.stock_transfers.columns.quantity_shipped')}
      subject={Subject.StockTransfer}
      pending={receive.isPending}
      onReceive={(params) => receive.mutateAsync(params)}
    />
  )
}

function ReceiptsCard({ transfer }: { transfer: StockTransfer }) {
  const queryKey = useResourceKey('stock-transfers', transfer.id, 'stock-receipts')
  return (
    <StockReceiptsCard
      queryKey={queryKey}
      fetch={() =>
        adminClient.stockTransfers.stockReceipts.list(transfer.id, { expand: ['items'] })
      }
    />
  )
}

/**
 * The lines once the van has left: what was sent, what each delivery has
 * counted in and refused so far.
 */
function LinesCard({ transfer }: { transfer: StockTransfer }) {
  const { t } = useTranslation()
  const items = transfer.items ?? []
  const anyOver = items.some((item) => item.quantity_over > 0)

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.stock_transfers.items_title')}</CardTitle>
      </CardHeader>
      <CardContent className="p-0">
        <Table scrollX roundedBottom>
          <TableHeader>
            <TableRow>
              <TableHead>{t('admin.inventory_lines.columns.variant')}</TableHead>
              <TableHead className="text-right">
                {t('admin.stock_transfers.columns.quantity_shipped')}
              </TableHead>
              <TableHead className="text-right">
                {t('admin.stock_transfers.columns.quantity_received')}
              </TableHead>
              <TableHead className="text-right">
                {t('admin.stock_transfers.columns.quantity_rejected')}
              </TableHead>
              {anyOver && (
                <TableHead className="text-right">
                  {t('admin.stock_transfers.columns.quantity_over')}
                </TableHead>
              )}
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
                <TableCell className="text-right tabular-nums">{item.quantity_shipped}</TableCell>
                <TableCell className="text-right tabular-nums">{item.quantity_received}</TableCell>
                <TableCell className="text-right tabular-nums">{item.quantity_rejected}</TableCell>
                {anyOver && (
                  <TableCell className="text-right tabular-nums">{item.quantity_over}</TableCell>
                )}
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </CardContent>
    </Card>
  )
}

/**
 * Title, status, and the transitions — laid out the way an order's header is:
 * the move that carries the transfer forward as a button on the right, the
 * cancellation in the menu beside it.
 */
function TransferHeader({ transfer }: { transfer: StockTransfer }) {
  const { t } = useTranslation()
  const { storeId } = useStore()
  const confirm = useConfirm()
  const navigate = useNavigate()
  const markReady = useMarkStockTransferReady(transfer.id)
  const markInTransit = useMarkStockTransferInTransit(transfer.id)
  const deleteTransfer = useDeleteStockTransfer()
  const markDraft = useMarkStockTransferDraft(transfer.id)
  const closeTransfer = useCloseStockTransfer(transfer.id)
  const [cancelOpen, setCancelOpen] = useState(false)
  const [closeOpen, setCloseOpen] = useState(false)

  const open = !isClosed(transfer.status)
  const shippable = transfer.status === 'draft' || transfer.status === 'ready_to_ship'

  async function handleShip() {
    const ok = await confirm({
      title: t('admin.stock_transfers.ship_confirm.title'),
      message: t('admin.stock_transfers.ship_confirm.message', {
        count: transfer.quantity_shipped_total,
      }),
      confirmLabel: t('admin.stock_transfers.actions.mark_in_transit'),
    })
    if (!ok) return
    await markInTransit.mutateAsync({}).catch(() => undefined)
  }

  // Back to the list on success: the record this page describes is gone, and
  // re-fetching it would 404.
  async function handleDelete() {
    const ok = await confirm({
      title: t('admin.stock_transfers.delete_confirm.title'),
      message: t('admin.stock_transfers.delete_confirm.message', { number: transfer.number }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return

    const deleted = await deleteTransfer
      .mutateAsync(transfer.id)
      .then(() => true)
      .catch(() => false)
    if (!deleted) return

    navigate({ to: '/$storeId/transfers', params: { storeId } })
  }

  return (
    <>
      {cancelOpen && (
        <TransferCancelDialog transfer={transfer} onClose={() => setCancelOpen(false)} />
      )}
      {closeOpen && (
        <CloseShortDialog
          title={t('admin.stock_transfers.close_confirm.title')}
          description={t('admin.stock_transfers.close_confirm.message', {
            outstanding: transfer.quantity_shipped_total - transfer.quantity_received_total,
          })}
          pending={closeTransfer.isPending}
          onConfirm={(reason) => closeTransfer.mutateAsync({ reason })}
          onClose={() => setCloseOpen(false)}
        />
      )}
      <PageHeader
        title={transfer.number}
        backTo="transfers"
        badges={<InventoryStatusBadge status={transfer.status} resource="stock_transfers" />}
        actions={
          open && (
            <Can I="update" a={Subject.StockTransfer}>
              {/* A draft is the only transfer whose contents are still a plan
                  rather than a record, which is what `editable` reports. */}
              {transfer.editable && (
                <Button variant="outline" asChild>
                  <Link
                    to="/$storeId/transfers/$transferId/edit"
                    params={{ storeId, transferId: transfer.id }}
                  >
                    <PencilIcon className="size-4" />
                    {t('admin.actions.edit')}
                  </Link>
                </Button>
              )}
              {/* Packing a draft is optional — a merchant already loading the
                  van can go straight to in transit — so it is the quieter of
                  the two. */}
              {transfer.status === 'draft' && (
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => markReady.mutateAsync().catch(() => undefined)}
                  disabled={markReady.isPending || (transfer.items_count ?? 0) === 0}
                >
                  {t('admin.stock_transfers.actions.mark_ready')}
                </Button>
              )}
              {/* Nothing has left the source yet, so unpacking costs nothing. */}
              {transfer.status === 'ready_to_ship' && (
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => markDraft.mutateAsync().catch(() => undefined)}
                  disabled={markDraft.isPending}
                >
                  <Undo2Icon className="size-4" />
                  {t('admin.stock_transfers.actions.mark_draft')}
                </Button>
              )}
              {shippable && (
                <Button type="button" onClick={handleShip} disabled={markInTransit.isPending}>
                  {t('admin.stock_transfers.actions.mark_in_transit')}
                </Button>
              )}
            </Can>
          )
        }
        dropdownItems={
          transfer.status === 'partially_received' && (
            <Can I="update" a={Subject.StockTransfer}>
              <DropdownMenuItem
                onClick={() => setCloseOpen(true)}
                disabled={closeTransfer.isPending}
              >
                <PackageCheckIcon className="size-4" />
                {t('admin.stock_transfers.actions.close_short')}
              </DropdownMenuItem>
            </Can>
          )
        }
        destructiveItems={
          open && (
            <>
              {/* A draft moved nothing, so it can simply be thrown away — the
                  same action the list offers. Past draft the transfer
                  describes a box that physically exists, which is what
                  cancelling is for, so both are offered on a draft and only
                  cancelling after it. */}
              {transfer.status === 'draft' && (
                <Can I="destroy" a={Subject.StockTransfer}>
                  <DropdownMenuItem
                    variant="destructive"
                    onClick={handleDelete}
                    disabled={deleteTransfer.isPending}
                  >
                    <Trash2Icon className="size-4" />
                    {t('admin.actions.delete')}
                  </DropdownMenuItem>
                </Can>
              )}
              <Can I="update" a={Subject.StockTransfer}>
                <DropdownMenuItem variant="destructive" onClick={() => setCancelOpen(true)}>
                  <XCircleIcon className="size-4" />
                  {t('admin.stock_transfers.actions.cancel_transfer')}
                </DropdownMenuItem>
              </Can>
            </>
          )
        }
        resource={{ id: transfer.id, number: transfer.number }}
        jsonPreview={{
          title: transfer.number,
          fetch: () => adminClient.stockTransfers.get(transfer.id, { expand: ['items'] }),
          endpoint: `/api/v3/admin/stock_transfers/${transfer.id}`,
          resolveLink: spreeJsonLinkResolver(storeId),
        }}
      />
    </>
  )
}
