import type { StockTransfer, StockTransferItem } from '@spree/admin-sdk'
import { Can, PageHeader, Subject, useStockLocations, useStore } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  DropdownMenuItem,
  RelativeTime,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
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
import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { InventoryStatusBadge } from '../../../../../components/spree/inventory-status-badge'
import { QuantityCell, QuantityHead } from '../../../../../components/spree/quantity-cell'
import { StockHistoryCard } from '../../../../../components/spree/stock-history-card'
import { TransferCancelDialog } from '../../../../../components/spree/transfer-cancel-dialog'
import { VariantLink } from '../../../../../components/spree/variant-link'
import {
  useMarkStockTransferInTransit,
  useMarkStockTransferReady,
  useReceiveStockTransfer,
  useStockTransfer,
} from '../../../../../hooks/use-stock-transfers'
import {
  DISCREPANCY_REASONS,
  isClosed,
  isInFlight,
} from '../../../../../schemas/inventory-operations'

export const Route = createFileRoute('/_authenticated/$storeId/products/transfers/$transferId')({
  component: StockTransferDetailPage,
})

function StockTransferDetailPage() {
  const { t } = useTranslation()
  const { transferId } = Route.useParams()
  const { data: transfer, isLoading } = useStockTransfer(transferId)

  if (isLoading || !transfer) {
    return <div className="p-4 text-sm text-muted-foreground">{t('admin.common.loading')}</div>
  }

  return (
    <div className="mx-auto flex w-full max-w-4xl flex-col gap-4 p-4">
      <TransferHeader transfer={transfer} />

      <SummaryCard transfer={transfer} />

      {transfer.status === 'draft' || transfer.status === 'ready_to_ship' ? (
        <PlannedItemsCard transfer={transfer} />
      ) : (
        <ReceiveCard transfer={transfer} />
      )}

      {/* Where the units on this trip came from and went — read on the
          destination warehouse, which is the shelf the merchant is
          reconciling. */}
      <StockHistoryCard
        stockLocationId={transfer.destination_location_id}
        title={t('admin.stock_transfers.history_title')}
      />
    </div>
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
        <dl className="grid grid-cols-3 gap-y-2 text-sm">
          <dt className="text-muted-foreground">{t('admin.stock_transfers.fields.source')}</dt>
          <dd className="col-span-2">
            <WarehouseLink
              storeId={storeId}
              id={transfer.source_location_id}
              name={transfer.source_location?.name ?? locationName(transfer.source_location_id)}
            />
          </dd>

          <dt className="text-muted-foreground">{t('admin.stock_transfers.fields.destination')}</dt>
          <dd className="col-span-2">
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
          <dd className="col-span-2 tabular-nums">
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
              <dd className="col-span-2">{transfer.reference}</dd>
            </>
          )}

          {transfer.notes && (
            <>
              <dt className="text-muted-foreground">{t('admin.stock_transfers.fields.notes')}</dt>
              <dd className="col-span-2 whitespace-pre-line">{transfer.notes}</dd>
            </>
          )}

          <dt className="text-muted-foreground">{t('admin.stock_transfers.fields.shipped_at')}</dt>
          <dd className="col-span-2">
            {transfer.shipped_at ? <RelativeTime iso={transfer.shipped_at} /> : '—'}
          </dd>

          <dt className="text-muted-foreground">{t('admin.stock_transfers.fields.received_at')}</dt>
          <dd className="col-span-2">
            {transfer.received_at ? <RelativeTime iso={transfer.received_at} /> : '—'}
          </dd>
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
          <Table roundedBottom>
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

/**
 * In transit and beyond: the receive screen.
 *
 * `quantity_received` is the running total for the line, so a second delivery
 * tops it up rather than starting over. The inputs are therefore seeded with
 * what has already arrived, not with what was sent: reopening a part-received
 * transfer has to show the shelf as it is.
 */
function ReceiveCard({ transfer }: { transfer: StockTransfer }) {
  const { t } = useTranslation()
  const items = transfer.items ?? []
  const receiveMutation = useReceiveStockTransfer(transfer.id)
  const editable = isInFlight(transfer.status)

  const [counts, setCounts] = useState<Record<string, number>>(() =>
    Object.fromEntries(items.map((item) => [item.id, item.quantity_received])),
  )
  const [reasons, setReasons] = useState<Record<string, string>>(() =>
    Object.fromEntries(items.map((item) => [item.id, item.discrepancy_reason ?? ''])),
  )

  const totalCounted = items.reduce((sum, item) => sum + (counts[item.id] ?? 0), 0)

  async function handleReceive() {
    await receiveMutation
      .mutateAsync({
        items: items.map((item) => {
          const received = counts[item.id] ?? item.quantity_received
          const reason = reasons[item.id]

          return {
            id: item.id,
            quantity_received: received,
            // Only while the line is under-received. The select hides once the
            // count is raised, but its state survives — and a fully received
            // line carrying "damaged in transit" is simply wrong.
            discrepancy_reason: received < item.quantity_shipped ? reason || undefined : undefined,
          }
        }),
      })
      .catch(() => undefined)
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.stock_transfers.receive_title')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col p-0">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>{t('admin.inventory_lines.columns.variant')}</TableHead>
              <TableHead className="text-right">
                {t('admin.stock_transfers.columns.quantity_shipped')}
              </TableHead>
              <QuantityHead>{t('admin.stock_transfers.columns.quantity_received')}</QuantityHead>
              <TableHead>{t('admin.stock_transfers.columns.discrepancy')}</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {items.map((item) => (
              <ReceiveRow
                key={item.id}
                item={item}
                editable={editable}
                count={counts[item.id] ?? item.quantity_received}
                reason={reasons[item.id] ?? ''}
                onCount={(value) => setCounts((prev) => ({ ...prev, [item.id]: value }))}
                onReason={(value) => setReasons((prev) => ({ ...prev, [item.id]: value }))}
              />
            ))}
          </TableBody>
        </Table>

        {editable && (
          <div className="flex items-center justify-between p-3">
            <p className="text-muted-foreground text-sm tabular-nums">
              {t('admin.stock_transfers.receive_running_total', {
                counted: totalCounted,
                shipped: transfer.quantity_shipped_total,
              })}
            </p>
            <Can I="update" a={Subject.StockTransfer}>
              <Button type="button" onClick={handleReceive} disabled={receiveMutation.isPending}>
                {receiveMutation.isPending
                  ? t('admin.actions.saving')
                  : t('admin.stock_transfers.actions.receive')}
              </Button>
            </Can>
          </div>
        )}
      </CardContent>
    </Card>
  )
}

function ReceiveRow({
  item,
  editable,
  count,
  reason,
  onCount,
  onReason,
}: {
  item: StockTransferItem
  editable: boolean
  count: number
  reason: string
  onCount: (value: number) => void
  onReason: (value: string) => void
}) {
  const { t } = useTranslation()
  const underReceived = count < item.quantity_shipped

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
      <TableCell className="text-right tabular-nums">{item.quantity_shipped}</TableCell>
      {/* Never below what is already on the shelf: taking units back off is a
          correction, not a receive. */}
      <QuantityCell
        editable={editable}
        value={editable ? count : item.quantity_received}
        min={item.quantity_received}
        max={item.quantity_shipped}
        label={t('admin.stock_transfers.columns.quantity_received')}
        onChange={onCount}
      />
      <TableCell>
        {editable && underReceived ? (
          <Select value={reason} onValueChange={onReason}>
            <SelectTrigger aria-label={t('admin.stock_transfers.columns.discrepancy')}>
              <SelectValue placeholder={t('admin.stock_transfers.discrepancy_placeholder')}>
                {(value) => (value ? t(`admin.stock_transfers.discrepancy_reasons.${value}`) : '')}
              </SelectValue>
            </SelectTrigger>
            <SelectContent>
              {DISCREPANCY_REASONS.map((value) => (
                <SelectItem key={value} value={value}>
                  {t(`admin.stock_transfers.discrepancy_reasons.${value}`)}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        ) : item.discrepancy_reason ? (
          <span className="text-sm">
            {t(`admin.stock_transfers.discrepancy_reasons.${item.discrepancy_reason}`, {
              defaultValue: item.discrepancy_reason,
            })}
          </span>
        ) : (
          '—'
        )}
      </TableCell>
    </TableRow>
  )
}

/**
 * Title, status, and the transitions — laid out the way an order's header is:
 * the move that carries the transfer forward as a button on the right, the
 * cancellation in the menu beside it.
 */
function TransferHeader({ transfer }: { transfer: StockTransfer }) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const markReady = useMarkStockTransferReady(transfer.id)
  const markInTransit = useMarkStockTransferInTransit(transfer.id)
  const [cancelOpen, setCancelOpen] = useState(false)

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

  return (
    <>
      {cancelOpen && (
        <TransferCancelDialog transfer={transfer} onClose={() => setCancelOpen(false)} />
      )}
      <PageHeader
        title={transfer.number}
        backTo="products/transfers"
        badges={<InventoryStatusBadge status={transfer.status} resource="stock_transfers" />}
        actions={
          open && (
            <Can I="update" a={Subject.StockTransfer}>
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
              {shippable && (
                <Button type="button" onClick={handleShip} disabled={markInTransit.isPending}>
                  {t('admin.stock_transfers.actions.mark_in_transit')}
                </Button>
              )}
            </Can>
          )
        }
        destructiveItems={
          open && (
            <Can I="update" a={Subject.StockTransfer}>
              <DropdownMenuItem variant="destructive" onClick={() => setCancelOpen(true)}>
                <XCircleIcon className="size-4" />
                {t('admin.stock_transfers.actions.cancel_transfer')}
              </DropdownMenuItem>
            </Can>
          )
        }
        resource={{ id: transfer.id, number: transfer.number }}
      />
    </>
  )
}
