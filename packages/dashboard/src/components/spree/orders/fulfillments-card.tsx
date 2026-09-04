import type { Delivery, Fulfillment, Order } from '@spree/admin-sdk'
import { useStockLocations } from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
  CardAction,
  CardContent,
  CardFooter,
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
  toastManager,
  useConfirm,
} from '@spree/dashboard-ui'
import {
  EllipsisVerticalIcon,
  MapPinIcon,
  PackageCheckIcon,
  PencilIcon,
  PlusIcon,
  PrinterIcon,
  SplitIcon,
  TagIcon,
  TruckIcon,
  XCircleIcon,
} from '@spree/dashboard-ui/icons'
import { type ReactNode, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useFulfillmentActions } from '../../../hooks/use-fulfillments'
import {
  type FulfillmentItemRow,
  fulfillmentItemRows,
  unfulfilledItemRows,
} from '../../../lib/fulfillment-items'
import { printPackingSlip } from '../../../lib/packing-slip'
import { FulfillmentDeliveries } from './fulfillment-deliveries'
import { FulfillmentDeliveryDialog } from './fulfillment-delivery-dialog'
import { FulfillmentEditDialog } from './fulfillment-edit-dialog'
import { FulfillmentFulfillForm } from './fulfillment-fulfill-form'
import { FulfillmentItemList } from './fulfillment-item-list'
import { FulfillmentLabelUploadDialog } from './fulfillment-label-upload-dialog'
import { ShippingDocuments } from './shipping-documents'
import { ShippingLabelRow } from './shipping-label-row'

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
 * Units no fulfillment has claimed, shaped for the create dialog. Only the
 * unclaimed remainder is offered: units already sitting in a fulfillment move
 * via Split, and shipped ones do not move at all.
 */
function orderUnits(order: Order): Array<{ itemId: string; label: string; quantity: number }> {
  return unfulfilledItemRows(order.items ?? [], order.fulfillments ?? []).map((row) => ({
    itemId: row.key,
    label: [row.name, row.optionsText].filter(Boolean).join(' — ') || row.key,
    quantity: row.quantity,
  }))
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

/** Creates a fulfillment for chosen quantities of the not-yet-claimed units. */
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
  const [error, setError] = useState<string | null>(null)
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
    setError(null)
    create.mutate(
      {
        stock_location_id: stockLocationId,
        // Always explicit: the backend reads a missing list as "every
        // not-yet-shipped unit", which would drain existing fulfillments.
        items,
      },
      {
        onSuccess: () => {
          setSelection({})
          setStockLocationId('')
          setError(null)
          onOpenChange(false)
        },
        // The mutation hook leaves a 422 untoasted because a form usually
        // shows it beside the offending field. This dialog has no such
        // field — the reason lives on the server ("that item has no
        // unfulfilled quantity") — so it is rendered here or nowhere.
        onError: (mutationError) => {
          setError(
            mutationError instanceof Error ? mutationError.message : t('admin.errors.unexpected'),
          )
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
            {error && (
              <p className="text-sm text-destructive" role="alert">
                {error}
              </p>
            )}

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
            disabled={!stockLocationId || items.length === 0 || create.isPending}
            onClick={handleSubmit}
          >
            {create.isPending ? t('admin.actions.saving') : t('admin.actions.create')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

// Which transitions the workflows actually accept, so the card does not
// present an action that can only 422.
const CAN_SHIP = ['unfulfilled']
const CAN_CANCEL = ['unfulfilled']
const CAN_EDIT = ['unfulfilled']
// Receipt is confirmed after handover, never before.
const CAN_MARK_DELIVERED = ['fulfilled']

function FulfillmentRow({ order, fulfillment }: { order: Order; fulfillment: Fulfillment }) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const orderId = order.id
  const { cancel, markDelivered, buyLabel, refundLabel, deleteLabel } =
    useFulfillmentActions(orderId)

  const [editOpen, setEditOpen] = useState(false)
  const [splitOpen, setSplitOpen] = useState(false)
  const [deliveryOpen, setDeliveryOpen] = useState(false)
  const [editingDelivery, setEditingDelivery] = useState<Delivery | undefined>()
  const [uploadOpen, setUploadOpen] = useState(false)
  const [fulfilling, setFulfilling] = useState(false)

  const editable = CAN_EDIT.includes(fulfillment.status)
  const splittable = editable && unitsOf(fulfillment).length > 0
  // A draft is not a commitment yet — nothing has been agreed, so nothing can
  // ship. The backend refuses too; this just keeps the button honest.
  const shippable = CAN_SHIP.includes(fulfillment.status) && order.status !== 'draft'
  // Confirming receipt is the merchant's next move on a parcel that has gone
  // out, so it sits in the card rather than behind the menu. Adding tracking
  // joins it as the primary action while the number is still missing.
  const selectedRate = (fulfillment.delivery_rates ?? []).find(
    (rate) => rate.id === fulfillment.selected_delivery_rate_id,
  )
  const deliverable = CAN_MARK_DELIVERED.includes(fulfillment.status)
  const deliveries = fulfillment.deliveries ?? []
  // At most one label binds a parcel: the workflows refuse a second while one
  // is active, and a refunded one stays as history.
  const activeLabel = (fulfillment.labels ?? []).find((label) => label.status !== 'refunded')
  // The label leads, fulfilled follows: print the label, pack the box, hand
  // it over — so buying the label is offered before the parcel ships.
  const canBuyLabel = shippable && fulfillment.provider_generates_labels && !activeLabel
  // Merchants without a carrier account buy postage elsewhere and still need
  // the file and the cost on the parcel.
  const canUploadLabel = shippable && !activeLabel

  return (
    <FulfillmentPanel
      status={fulfillment.status}
      location={fulfillment.stock_location?.name}
      meta={
        fulfillment.fulfilled_at && (
          <span className="text-muted-foreground text-xs">
            <RelativeTime
              iso={fulfillment.fulfilled_at}
              prefix={t('admin.orders.detail.tracking.fulfilled_prefix')}
              fallback=""
            />
          </span>
        )
      }
      actions={
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="ghost" size="icon-xs">
              <EllipsisVerticalIcon className="size-4" />
              <span className="sr-only">{t('admin.actions.actions_menu')}</span>
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            {editable && (
              <DropdownMenuItem onClick={() => setEditOpen(true)}>
                <PencilIcon className="size-4" />
                {t('admin.actions.edit')}
              </DropdownMenuItem>
            )}

            {splittable && (
              <DropdownMenuItem onClick={() => setSplitOpen(true)}>
                <SplitIcon className="size-4" />
                {t('admin.orders.detail.fulfillments.split')}
              </DropdownMenuItem>
            )}

            <DropdownMenuItem onClick={() => printPackingSlip(order, fulfillment, t)}>
              <PrinterIcon className="size-4" />
              {t('admin.orders.detail.fulfillments.print_packing_slip')}
            </DropdownMenuItem>

            <DropdownMenuItem
              onClick={() => {
                setEditingDelivery(undefined)
                setDeliveryOpen(true)
              }}
            >
              <TruckIcon className="size-4" />
              {t('admin.orders.detail.fulfillments.add_delivery')}
            </DropdownMenuItem>

            {canUploadLabel && (
              <DropdownMenuItem onClick={() => setUploadOpen(true)}>
                <TagIcon className="size-4" />
                {t('admin.orders.detail.fulfillments.upload_label')}
              </DropdownMenuItem>
            )}

            {CAN_CANCEL.includes(fulfillment.status) && (
              <>
                <DropdownMenuSeparator />
                <DropdownMenuItem
                  variant="destructive"
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
      }
    >
      {(fulfillment.delivery_method || Number.parseFloat(fulfillment.cost) > 0) && (
        <CardContent className="flex items-center justify-between border-b border-border-subtle py-3 text-sm">
          <span className="text-muted-foreground">
            {/* The selected rate names the carrier service that actually
                carries this parcel ("USPS GroundAdvantage"); the method is
                the account it was quoted through ("EasyPost"), which one
                carrier method fans out into many services. */}
            {selectedRate?.name ??
              fulfillment.delivery_method?.name ??
              t('admin.pages.orders.detail.no_delivery_method')}
          </span>
          <span>{fulfillment.display_cost}</span>
        </CardContent>
      )}

      {activeLabel && !fulfilling && (
        <ShippingLabelRow
          label={activeLabel}
          isRefunding={refundLabel.isPending}
          onRefund={() =>
            refundLabel.mutate({ fulfillmentId: fulfillment.id, labelId: activeLabel.id })
          }
          onDelete={() =>
            deleteLabel.mutate({ fulfillmentId: fulfillment.id, labelId: activeLabel.id })
          }
        />
      )}

      {!fulfilling && <ShippingDocuments documents={fulfillment.documents} />}

      {!fulfilling && (
        <FulfillmentDeliveries
          orderId={orderId}
          fulfillmentId={fulfillment.id}
          deliveries={deliveries}
          onEdit={(delivery) => {
            setEditingDelivery(delivery)
            setDeliveryOpen(true)
          }}
        />
      )}

      {fulfilling ? (
        <FulfillmentFulfillForm
          order={order}
          fulfillment={fulfillment}
          onDone={() => setFulfilling(false)}
        />
      ) : (
        <>
          <FulfillmentItemList rows={fulfillmentItemRows(fulfillment, order.items ?? [])} />

          {shippable && (
            <CardFooter className="justify-end gap-2 py-3">
              {canBuyLabel && (
                <Button
                  type="button"
                  size="sm"
                  variant="outline"
                  disabled={buyLabel.isPending}
                  onClick={async () => {
                    // Buying a label charges the carrier account, so it gets
                    // an explicit yes even though nothing is destroyed.
                    if (
                      await confirm({
                        message: selectedRate
                          ? t('admin.orders.detail.fulfillments.buy_label_confirm_rate', {
                              rate: selectedRate.name,
                              cost: selectedRate.display_cost,
                            })
                          : t('admin.orders.detail.fulfillments.buy_label_confirm'),
                        confirmLabel: t('admin.orders.detail.fulfillments.buy_label'),
                      })
                    ) {
                      // Toasted here rather than on the hook: the same
                      // mutation backs the upload sheet, which shows its
                      // rejection inline. A button has nowhere to put one.
                      buyLabel.mutate(
                        { fulfillmentId: fulfillment.id },
                        {
                          onError: (mutationError) => {
                            toastManager.add({
                              type: 'error',
                              title:
                                mutationError instanceof Error
                                  ? mutationError.message
                                  : t('admin.errors.unexpected'),
                            })
                          },
                        },
                      )
                    }
                  }}
                >
                  <TagIcon data-icon="inline-start" />
                  {buyLabel.isPending
                    ? t('admin.actions.saving')
                    : t('admin.orders.detail.fulfillments.buy_label')}
                </Button>
              )}

              <Button type="button" size="sm" onClick={() => setFulfilling(true)}>
                <TruckIcon data-icon="inline-start" />
                {t('admin.orders.fulfill.action')}
              </Button>
            </CardFooter>
          )}

          {deliverable && (
            <CardFooter className="justify-end gap-2 py-3">
              <Button
                type="button"
                size="sm"
                variant={deliveries.length === 0 ? 'outline' : 'default'}
                disabled={markDelivered.isPending}
                onClick={() => markDelivered.mutate(fulfillment.id)}
              >
                <PackageCheckIcon data-icon="inline-start" />
                {t('admin.orders.detail.fulfillments.mark_delivered')}
              </Button>

              <Button
                type="button"
                size="sm"
                variant={deliveries.length === 0 ? 'default' : 'outline'}
                onClick={() => {
                  setEditingDelivery(undefined)
                  setDeliveryOpen(true)
                }}
              >
                <PlusIcon data-icon="inline-start" />
                {t('admin.orders.detail.fulfillments.add_tracking')}
              </Button>
            </CardFooter>
          )}
        </>
      )}

      {editOpen && (
        <FulfillmentEditDialog
          order={order}
          fulfillment={fulfillment}
          open={editOpen}
          onOpenChange={setEditOpen}
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

      {deliveryOpen && (
        <FulfillmentDeliveryDialog
          orderId={orderId}
          fulfillmentId={fulfillment.id}
          delivery={editingDelivery}
          open={deliveryOpen}
          onOpenChange={(open) => {
            setDeliveryOpen(open)
            if (!open) setEditingDelivery(undefined)
          }}
        />
      )}

      {uploadOpen && (
        <FulfillmentLabelUploadDialog
          orderId={orderId}
          fulfillmentId={fulfillment.id}
          currency={order.currency}
          open={uploadOpen}
          onOpenChange={setUploadOpen}
        />
      )}
    </FulfillmentPanel>
  )
}

/**
 * The chrome every fulfillment panel shares: a status badge, where it ships
 * from, and the items in it.
 *
 * A draft order has no `Fulfillment` record yet — no id, no location, nothing
 * to act on — so the two callers pass what they have rather than one of them
 * inventing a record. What they do share is how it looks.
 */
function FulfillmentPanel({
  status,
  location,
  meta,
  actions,
  children,
}: {
  status: string
  /** Where it ships from. Absent until a fulfillment exists. */
  location?: string | null
  /** Trailing header detail, e.g. when it shipped. */
  meta?: ReactNode
  /** The panel's own menu. Absent when there is nothing to act on. */
  actions?: ReactNode
  children: ReactNode
}) {
  return (
    <Card variant="nested">
      <CardHeader>
        <CardTitle className="min-w-0 text-sm font-normal">
          <StatusBadge status={status} />
          {location && (
            <div className="flex min-w-0 items-center gap-1.5 text-muted-foreground text-xs">
              <MapPinIcon className="size-3 shrink-0" />
              {/* The card clips its overflow, so a long warehouse name has to
                  truncate here or it is simply cut off. */}
              <span className="truncate">{location}</span>
            </div>
          )}
          {meta}
        </CardTitle>
        {actions && <CardAction>{actions}</CardAction>}
      </CardHeader>
      {children}
    </Card>
  )
}

/**
 * Units nobody has put into a fulfillment yet. Reads like a fulfillment group
 * so the eye can compare it against the real ones, minus the status and number
 * it does not have.
 */
function UnfulfilledItems({ rows, canCreate }: { rows: FulfillmentItemRow[]; canCreate: boolean }) {
  const { t } = useTranslation()
  const totalUnits = rows.reduce((sum, row) => sum + row.quantity, 0)

  // Deliberately not a FulfillmentPanel: these units have no fulfillment, and
  // borrowing the panel's status badge and location slot made them read as a
  // record that already exists. What the operator needs to see is that
  // something is owed and nothing is carrying it yet.
  return (
    <div className="flex flex-col gap-2 rounded-lg border border-border-subtle border-dashed p-4">
      <div className="flex flex-wrap items-baseline justify-between gap-2">
        <span className="font-medium text-sm">
          {t('admin.orders.detail.fulfillments.awaiting_fulfillment', { count: totalUnits })}
        </span>
        <span className="text-muted-foreground text-xs">
          {canCreate
            ? t('admin.orders.detail.fulfillments.awaiting_hint')
            : t('admin.orders.detail.fulfillments.awaiting_hint_draft')}
        </span>
      </div>

      <FulfillmentItemList rows={rows} />
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

  const fulfillments = order.fulfillments ?? []
  const lineItems = order.items ?? []
  const unfulfilled = unfulfilledItemRows(lineItems, fulfillments)

  // Manual creation is a completed-order operation: Fulfillments::Create
  // rejects it otherwise ("Fulfillments can only be created manually on
  // completed orders"). And it is only for units no fulfillment has claimed —
  // once everything is allocated, rearranging lives on each fulfillment's
  // Split action, not here.
  const canCreate = !!order.completed_at && unfulfilled.length > 0

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
              <UnfulfilledItems rows={unfulfilled} canCreate={canCreate} />
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
    </>
  )
}
