import type { Fulfillment, Order } from '@spree/admin-sdk'
import { adminClient } from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  RelativeTime,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  StatusBadge,
  useConfirm,
} from '@spree/dashboard-ui'
import {
  EllipsisVerticalIcon,
  MapPinIcon,
  PackageIcon,
  PencilIcon,
  PlusIcon,
  RotateCcwIcon,
  SplitIcon,
  TagIcon,
  TruckIcon,
  XCircleIcon,
} from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useFulfillmentActions } from '../../../hooks/use-fulfillments'
import { useOrderMutation } from '../../../hooks/use-order'
import { useStockLocations } from '../../../hooks/use-stock-locations'
import {
  type FulfillmentItemRow,
  fulfillmentItemRows,
  hasFulfillableUnits,
  unfulfilledItemRows,
} from '../../../lib/fulfillment-items'
import { FulfillmentEditDialog } from './fulfillment-edit-dialog'
import { FulfillmentItemList } from './fulfillment-item-list'
import { AddLineItemDialog, EditQuantityDialog } from './line-item-dialogs'

/**
 * A unit sitting in one fulfillment. Splitting moves units per variant rather
 * than per line item, because that is what the backend's transfer takes.
 */
type FulfillmentUnit = {
  variantId: string
  label: string
  quantity: number
}

function unitsOf(fulfillment: Fulfillment): FulfillmentUnit[] {
  return (fulfillment.fulfillment_items ?? []).flatMap((item) => {
    if (!item.variant_id) return []
    return [
      {
        variantId: item.variant_id,
        label: [item.name, item.options_text].filter(Boolean).join(' — ') || item.variant_id,
        quantity: item.quantity,
      },
    ]
  })
}

/**
 * Line items still available to put into a new fulfillment. The backend moves
 * units out of their existing fulfillments, so everything on the order is
 * offered — it re-shapes the source rather than refusing.
 */
function orderUnits(order: Order): Array<{ itemId: string; label: string; quantity: number }> {
  return (order.items ?? []).map((item) => ({
    itemId: item.id,
    label: [item.name, item.options_text].filter(Boolean).join(' — ') || item.id,
    quantity: item.quantity,
  }))
}

function EditTrackingDialog({
  orderId,
  fulfillment,
  open,
  onOpenChange,
}: {
  orderId: string
  fulfillment: Fulfillment
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { update } = useFulfillmentActions(orderId)
  const [tracking, setTracking] = useState(fulfillment.tracking ?? '')

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.orders.detail.tracking.edit_title')}</DialogTitle>
          <DialogDescription>{t('admin.orders.detail.tracking.description')}</DialogDescription>
        </DialogHeader>
        <DialogBody>
          <FieldGroup>
            <Field>
              <FieldLabel htmlFor="tracking">{t('admin.orders.detail.tracking.label')}</FieldLabel>
              <Input
                id="tracking"
                value={tracking}
                onChange={(event) => setTracking(event.target.value)}
              />
            </Field>
          </FieldGroup>
        </DialogBody>
        <DialogFooter>
          <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
            {t('admin.actions.cancel')}
          </Button>
          <Button
            type="button"
            disabled={update.isPending}
            onClick={() =>
              update.mutate(
                { fulfillmentId: fulfillment.id, tracking },
                { onSuccess: () => onOpenChange(false) },
              )
            }
          >
            {update.isPending ? t('admin.actions.saving') : t('admin.actions.save')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

/**
 * Moves units into a new fulfillment. One variant per submit, because that is
 * the granularity the backend's transfer works at — splitting several variants
 * apart is several splits.
 */
function SplitFulfillmentDialog({
  orderId,
  fulfillment,
  open,
  onOpenChange,
}: {
  orderId: string
  fulfillment: Fulfillment
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const { split } = useFulfillmentActions(orderId)
  const { data } = useStockLocations()

  const units = unitsOf(fulfillment)
  const [variantId, setVariantId] = useState(units[0]?.variantId ?? '')
  const [quantity, setQuantity] = useState(1)
  const [stockLocationId, setStockLocationId] = useState(fulfillment.stock_location_id ?? '')

  const unit = units.find((candidate) => candidate.variantId === variantId)
  const totalUnits = units.reduce((sum, candidate) => sum + candidate.quantity, 0)

  // Splitting off everything would leave the source empty — the backend
  // destroys it, which is a move rather than a split and almost never what was
  // meant. Changing the origin of the whole fulfillment does that properly.
  const wouldEmptySource = quantity >= totalUnits
  const invalid = !unit || quantity < 1 || quantity > unit.quantity || wouldEmptySource

  const variantOptions = units.map((candidate) => ({
    value: candidate.variantId,
    label: `${candidate.label} (${candidate.quantity})`,
  }))
  const locationOptions = (data?.data ?? []).map((location) => ({
    value: location.id,
    label: location.name,
  }))

  async function handleSubmit() {
    if (invalid) return
    if (
      !(await confirm({
        message: t('admin.orders.detail.fulfillments.confirm_split'),
        variant: 'destructive',
        confirmLabel: t('admin.orders.detail.fulfillments.split'),
      }))
    ) {
      return
    }

    split.mutate(
      {
        fulfillmentId: fulfillment.id,
        variant_id: variantId,
        quantity,
        stock_location_id: stockLocationId || undefined,
      },
      { onSuccess: () => onOpenChange(false) },
    )
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.orders.detail.fulfillments.split_title')}</DialogTitle>
          <DialogDescription>
            {t('admin.orders.detail.fulfillments.split_description')}
          </DialogDescription>
        </DialogHeader>
        <DialogBody>
          <FieldGroup>
            <Field>
              <FieldLabel htmlFor="split-variant">
                {t('admin.orders.detail.fulfillments.split_item')}
              </FieldLabel>
              <Select
                items={variantOptions}
                value={variantId}
                onValueChange={(value) => {
                  setVariantId(value as string)
                  setQuantity(1)
                }}
              >
                <SelectTrigger id="split-variant">
                  <SelectValue placeholder={t('admin.common.select_placeholder')} />
                </SelectTrigger>
                <SelectContent>
                  {variantOptions.map((option) => (
                    <SelectItem key={option.value} value={option.value}>
                      {option.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </Field>

            <Field>
              <FieldLabel htmlFor="split-quantity">
                {t('admin.orders.detail.fulfillments.split_quantity')}
              </FieldLabel>
              <Input
                id="split-quantity"
                type="number"
                min={1}
                max={unit?.quantity ?? 1}
                value={quantity}
                onChange={(event) => setQuantity(Number(event.target.value))}
              />
              {wouldEmptySource && (
                <FieldError>{t('admin.orders.detail.fulfillments.split_would_empty')}</FieldError>
              )}
            </Field>

            {locationOptions.length > 0 && (
              <Field>
                <FieldLabel htmlFor="split-location">
                  {t('admin.orders.detail.fulfillments.ships_from')}
                </FieldLabel>
                <Select
                  items={locationOptions}
                  value={stockLocationId}
                  onValueChange={(value) => setStockLocationId(value as string)}
                >
                  <SelectTrigger id="split-location">
                    <SelectValue placeholder={t('admin.common.select_placeholder')} />
                  </SelectTrigger>
                  <SelectContent>
                    {locationOptions.map((option) => (
                      <SelectItem key={option.value} value={option.value}>
                        {option.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </Field>
            )}
          </FieldGroup>
        </DialogBody>
        <DialogFooter>
          <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
            {t('admin.actions.cancel')}
          </Button>
          <Button type="button" disabled={invalid || split.isPending} onClick={handleSubmit}>
            {split.isPending
              ? t('admin.actions.saving')
              : t('admin.orders.detail.fulfillments.split')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

/** Creates a fulfillment, moving the chosen quantities out of the existing ones. */
function CreateFulfillmentDialog({
  order,
  open,
  onOpenChange,
}: {
  order: Order
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { create } = useFulfillmentActions(order.id)
  const { data } = useStockLocations()

  const units = orderUnits(order)
  const locations = data?.data ?? []
  const [stockLocationId, setStockLocationId] = useState('')
  const [selection, setSelection] = useState<Record<string, number>>({})

  const items = Object.entries(selection)
    .filter(([, quantity]) => quantity > 0)
    .map(([itemId, quantity]) => ({ item_id: itemId, quantity }))

  const locationOptions = locations.map((location) => ({
    value: location.id,
    label: location.name,
  }))

  function handleSubmit() {
    if (!stockLocationId) return
    create.mutate(
      {
        stock_location_id: stockLocationId,
        items: items.length > 0 ? items : undefined,
      },
      {
        onSuccess: () => {
          setSelection({})
          setStockLocationId('')
          onOpenChange(false)
        },
      },
    )
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.orders.detail.fulfillments.create_title')}</DialogTitle>
          <DialogDescription>
            {t('admin.orders.detail.fulfillments.create_description')}
          </DialogDescription>
        </DialogHeader>
        <DialogBody>
          <FieldGroup>
            <Field>
              <FieldLabel htmlFor="create-location">
                {t('admin.orders.detail.fulfillments.ships_from')}
              </FieldLabel>
              <Select
                items={locationOptions}
                value={stockLocationId}
                onValueChange={(value) => setStockLocationId(value as string)}
              >
                <SelectTrigger id="create-location">
                  <SelectValue placeholder={t('admin.common.select_placeholder')} />
                </SelectTrigger>
                <SelectContent>
                  {locationOptions.map((option) => (
                    <SelectItem key={option.value} value={option.value}>
                      {option.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </Field>

            <Field>
              <FieldLabel>{t('admin.orders.detail.fulfillments.create_items')}</FieldLabel>
              <div className="flex flex-col gap-2">
                {units.map((unit) => (
                  <div
                    key={unit.itemId}
                    className="flex items-center justify-between gap-4 rounded-lg border p-3"
                  >
                    <span className="text-sm truncate">{unit.label}</span>
                    <Input
                      type="number"
                      min={0}
                      max={unit.quantity}
                      className="w-20"
                      aria-label={unit.label}
                      value={selection[unit.itemId] ?? 0}
                      onChange={(event) =>
                        setSelection((current) => ({
                          ...current,
                          [unit.itemId]: Math.max(
                            0,
                            Math.min(Number(event.target.value), unit.quantity),
                          ),
                        }))
                      }
                    />
                  </div>
                ))}
              </div>
            </Field>
          </FieldGroup>
        </DialogBody>
        <DialogFooter>
          <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
            {t('admin.actions.cancel')}
          </Button>
          <Button
            type="button"
            disabled={!stockLocationId || create.isPending}
            onClick={handleSubmit}
          >
            {create.isPending ? t('admin.actions.saving') : t('admin.actions.create')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

// Which transitions the backend's state machine actually offers, so the menu
// does not present an action that can only 422.
const CAN_SHIP = ['ready', 'ready_for_pickup']
const CAN_CANCEL = ['pending', 'ready', 'ready_for_pickup']
const CAN_EDIT = ['pending', 'ready', 'ready_for_pickup']

function FulfillmentRow({ order, fulfillment }: { order: Order; fulfillment: Fulfillment }) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const orderId = order.id
  const { fulfill, cancel, resume } = useFulfillmentActions(orderId)

  const [editOpen, setEditOpen] = useState(false)
  const [trackingOpen, setTrackingOpen] = useState(false)
  const [splitOpen, setSplitOpen] = useState(false)

  const editable = CAN_EDIT.includes(fulfillment.status)
  const splittable = editable && unitsOf(fulfillment).length > 0

  return (
    <div className="rounded-lg border p-4 flex flex-col gap-3">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <StatusBadge status={fulfillment.status} />
          <span className="text-sm font-medium">{fulfillment.number}</span>
        </div>
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="ghost" size="icon-xs">
              <EllipsisVerticalIcon className="size-4" />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            {editable && (
              <DropdownMenuItem onClick={() => setEditOpen(true)}>
                <PencilIcon className="size-4" />
                {t('admin.actions.edit')}
              </DropdownMenuItem>
            )}

            <DropdownMenuItem onClick={() => setTrackingOpen(true)}>
              <TagIcon className="size-4" />
              {fulfillment.tracking
                ? t('admin.orders.detail.tracking.edit_title')
                : t('admin.orders.detail.tracking.add_title')}
            </DropdownMenuItem>

            {splittable && (
              <DropdownMenuItem onClick={() => setSplitOpen(true)}>
                <SplitIcon className="size-4" />
                {t('admin.orders.detail.fulfillments.split')}
              </DropdownMenuItem>
            )}

            {CAN_SHIP.includes(fulfillment.status) && (
              <DropdownMenuItem
                onClick={async () => {
                  if (
                    await confirm({
                      message: t('admin.orders.detail.confirm.ship_message'),
                      variant: 'default',
                      confirmLabel: t('admin.pages.orders.detail.actions.ship'),
                    })
                  ) {
                    fulfill.mutate(fulfillment.id)
                  }
                }}
              >
                <TruckIcon className="size-4" />
                {t('admin.pages.orders.detail.actions.ship')}
              </DropdownMenuItem>
            )}

            {fulfillment.status === 'canceled' && (
              <DropdownMenuItem onClick={() => resume.mutate(fulfillment.id)}>
                <RotateCcwIcon className="size-4" />
                {t('admin.pages.orders.detail.actions.resume')}
              </DropdownMenuItem>
            )}

            {CAN_CANCEL.includes(fulfillment.status) && (
              <>
                <DropdownMenuSeparator />
                <DropdownMenuItem
                  className="text-destructive focus:text-destructive"
                  onClick={async () => {
                    if (
                      await confirm({
                        message: t('admin.orders.detail.confirm.cancel_shipment_message'),
                        variant: 'destructive',
                        confirmLabel: t('admin.actions.cancel'),
                      })
                    ) {
                      cancel.mutate(fulfillment.id)
                    }
                  }}
                >
                  <XCircleIcon className="size-4" />
                  {t('admin.actions.cancel')}
                </DropdownMenuItem>
              </>
            )}
          </DropdownMenuContent>
        </DropdownMenu>
      </div>

      {(fulfillment.delivery_method || Number.parseFloat(fulfillment.cost) > 0) && (
        <div className="flex items-center justify-between text-sm">
          <span className="text-muted-foreground">
            {fulfillment.delivery_method?.name ?? t('admin.pages.orders.detail.no_delivery_method')}
          </span>
          <span>{fulfillment.display_cost}</span>
        </div>
      )}

      {fulfillment.stock_location && (
        <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
          <MapPinIcon className="size-3" />
          {fulfillment.stock_location.name}
        </div>
      )}

      {fulfillment.tracking && (
        <div className="text-sm">
          <span className="text-muted-foreground">
            {t('admin.orders.detail.tracking.prefix')}:{' '}
          </span>
          {fulfillment.tracking_url ? (
            <a
              href={fulfillment.tracking_url}
              target="_blank"
              rel="noopener noreferrer"
              className="text-blue-600 hover:underline"
            >
              {fulfillment.tracking}
            </a>
          ) : (
            <span>{fulfillment.tracking}</span>
          )}
        </div>
      )}

      {fulfillment.fulfilled_at && (
        <span className="text-xs text-muted-foreground">
          <RelativeTime
            iso={fulfillment.fulfilled_at}
            prefix={t('admin.orders.detail.tracking.shipped_prefix')}
            fallback=""
          />
        </span>
      )}

      <FulfillmentItemList rows={fulfillmentItemRows(fulfillment, order.items ?? [])} />

      {editOpen && (
        <FulfillmentEditDialog
          order={order}
          fulfillment={fulfillment}
          open={editOpen}
          onOpenChange={setEditOpen}
        />
      )}

      {trackingOpen && (
        <EditTrackingDialog
          orderId={orderId}
          fulfillment={fulfillment}
          open={trackingOpen}
          onOpenChange={setTrackingOpen}
        />
      )}

      {splitOpen && (
        <SplitFulfillmentDialog
          orderId={orderId}
          fulfillment={fulfillment}
          open={splitOpen}
          onOpenChange={setSplitOpen}
        />
      )}
    </div>
  )
}

/**
 * Units nobody has put into a fulfillment yet. Reads like a fulfillment group
 * so the eye can compare it against the real ones, minus the status and number
 * it does not have. Line items are still editable here — once units belong to
 * a fulfillment they are edited through that fulfillment instead.
 */
function UnfulfilledGroup({
  orderId,
  rows,
  onEditItem,
}: {
  orderId: string
  rows: FulfillmentItemRow[]
  onEditItem: (row: FulfillmentItemRow) => void
}) {
  const { t } = useTranslation()

  const deleteMutation = useOrderMutation(orderId, (lineItemId: string) =>
    adminClient.orders.items.delete(orderId, lineItemId),
  )

  const totalUnits = rows.reduce((sum, row) => sum + row.quantity, 0)

  return (
    <div className="rounded-lg border p-4 flex flex-col gap-3">
      <div className="flex items-center gap-2">
        <PackageIcon className="size-4 text-muted-foreground" />
        <span className="text-sm font-medium">
          {t('admin.orders.detail.fulfillments.unfulfilled', { count: totalUnits })}
        </span>
      </div>

      <FulfillmentItemList
        rows={rows}
        onEdit={onEditItem}
        onRemove={(row) => row.lineItem && deleteMutation.mutate(row.lineItem.id)}
        // Removal deletes the whole line item, so it is only offered while
        // every one of its units is still unclaimed — otherwise it would
        // silently pull units out of an existing fulfillment too.
        canRemove={(row) => !!row.lineItem && row.quantity === row.lineItem.quantity}
      />
    </div>
  )
}

/**
 * Fulfillments on an order, editable while they are still open: which priced
 * service carries them, where they ship from, and how the units are grouped.
 * Once shipped or canceled they read back flat, since the backend refuses the
 * writes anyway.
 *
 * Each group lists the items it carries, so a multi-fulfillment order says
 * which goods went where rather than leaving that to be inferred from a
 * separate basket-wide list.
 */
export function FulfillmentsCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  const [createOpen, setCreateOpen] = useState(false)
  const [addItemOpen, setAddItemOpen] = useState(false)
  const [editItem, setEditItem] = useState<{ id: string; quantity: number } | null>(null)

  const fulfillments = order.fulfillments ?? []
  const lineItems = order.items ?? []
  const unfulfilled = unfulfilledItemRows(lineItems, fulfillments)

  // Manual creation is a completed-order operation: Fulfillments::Create
  // rejects it otherwise ("Fulfillments can only be created manually on
  // completed orders"). A draft's fulfillments come from the delivery step.
  // It also needs units it can actually move — offering it on a fully shipped
  // order would only ever produce an empty fulfillment.
  const canCreate = !!order.completed_at && hasFulfillableUnits(lineItems, fulfillments)

  const groupCount = fulfillments.length + (unfulfilled.length > 0 ? 1 : 0)

  return (
    <>
      <Card>
        <CardHeader>
          <CardTitle>
            <TruckIcon className="size-4" />
            {t('admin.pages.orders.detail.section_fulfillments')}
            {groupCount > 0 && <Badge variant="outline">{groupCount}</Badge>}
          </CardTitle>
          <CardAction className="flex items-center gap-2">
            {order.fulfillment_status && <StatusBadge status={order.fulfillment_status} />}
            <Button size="sm" variant="outline" onClick={() => setAddItemOpen(true)}>
              <PlusIcon data-icon="inline-start" />
              {t('admin.orders.detail.fulfillments.add_item')}
            </Button>
            {canCreate && (
              <Button size="sm" variant="outline" onClick={() => setCreateOpen(true)}>
                <PlusIcon data-icon="inline-start" />
                {t('admin.orders.detail.fulfillments.create_title')}
              </Button>
            )}
          </CardAction>
        </CardHeader>
        {groupCount === 0 ? (
          <CardContent>
            <p className="text-center text-muted-foreground py-8">
              {t('admin.orders.detail.fulfillments.empty')}
            </p>
          </CardContent>
        ) : (
          <CardContent className="flex flex-col gap-4">
            {unfulfilled.length > 0 && (
              <UnfulfilledGroup
                orderId={order.id}
                rows={unfulfilled}
                onEditItem={(row) =>
                  row.lineItem &&
                  setEditItem({ id: row.lineItem.id, quantity: row.lineItem.quantity })
                }
              />
            )}
            {fulfillments.map((fulfillment) => (
              <FulfillmentRow key={fulfillment.id} order={order} fulfillment={fulfillment} />
            ))}
          </CardContent>
        )}
      </Card>

      {createOpen && (
        <CreateFulfillmentDialog order={order} open={createOpen} onOpenChange={setCreateOpen} />
      )}

      <AddLineItemDialog orderId={order.id} open={addItemOpen} onOpenChange={setAddItemOpen} />

      {editItem && (
        <EditQuantityDialog
          orderId={order.id}
          lineItemId={editItem.id}
          currentQuantity={editItem.quantity}
          open={!!editItem}
          onOpenChange={(open) => !open && setEditItem(null)}
        />
      )}
    </>
  )
}
