import type { Fulfillment, Order } from '@spree/admin-sdk'
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
  PackageCheckIcon,
  PackageIcon,
  PencilIcon,
  PlusIcon,
  PrinterIcon,
  RotateCcwIcon,
  SplitIcon,
  TagIcon,
  TruckIcon,
  XCircleIcon,
} from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useFulfillmentActions } from '../../../hooks/use-fulfillments'
import { useStockLocations } from '../../../hooks/use-stock-locations'
import {
  type FulfillmentItemRow,
  fulfillmentItemRows,
  unfulfilledItemRows,
} from '../../../lib/fulfillment-items'
import { printPackingSlip } from '../../../lib/packing-slip'
import { FulfillmentEditDialog } from './fulfillment-edit-dialog'
import { FulfillmentFulfillForm } from './fulfillment-fulfill-form'
import { FulfillmentItemList } from './fulfillment-item-list'
import { FulfillmentTrackingDialog } from './fulfillment-tracking-dialog'

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
        // Always explicit: the backend reads a missing list as "every
        // not-yet-shipped unit", which would drain existing fulfillments.
        items,
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
  const { cancel, resume, markDelivered, purchaseLabel } = useFulfillmentActions(orderId)

  const [editOpen, setEditOpen] = useState(false)
  const [splitOpen, setSplitOpen] = useState(false)
  const [trackingOpen, setTrackingOpen] = useState(false)
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
  // The label leads, fulfilled follows: print the label, pack the box, hand
  // it over — so buying the label is offered before the parcel ships.
  const labelDocument = (fulfillment.documents ?? []).find((doc) => doc.kind === 'label')
  const canBuyLabel = shippable && fulfillment.provider_generates_labels && !labelDocument
  const trackable = deliverable && !fulfillment.tracking

  return (
    <div className="rounded-lg border flex flex-col">
      <div className="flex items-center justify-between border-b p-3">
        <div className="flex items-center gap-2">
          <StatusBadge status={fulfillment.status} />
          {fulfillment.stock_location && (
            <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
              <MapPinIcon className="size-3" />
              {fulfillment.stock_location.name}
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

            {deliverable && fulfillment.tracking && (
              <DropdownMenuItem onClick={() => setTrackingOpen(true)}>
                <TruckIcon className="size-4" />
                {t('admin.orders.detail.fulfillments.edit_tracking_title')}
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
        <div className="flex items-center justify-between text-sm p-3 border-b">
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
        </div>
      )}

      {fulfillment.tracking && !fulfilling && (
        <div className="text-sm p-3 border-b">
          <span className="text-muted-foreground">
            {fulfillment.tracking_carrier_name ?? t('admin.orders.detail.tracking.prefix')}:{' '}
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
            <div className="flex justify-end gap-2 p-3 border-t">
              {canBuyLabel && (
                <Button
                  type="button"
                  size="sm"
                  variant="outline"
                  disabled={purchaseLabel.isPending}
                  onClick={() => purchaseLabel.mutate(fulfillment.id)}
                >
                  <TagIcon data-icon="inline-start" />
                  {purchaseLabel.isPending
                    ? t('admin.actions.saving')
                    : t('admin.orders.detail.fulfillments.buy_label')}
                </Button>
              )}

              {labelDocument && (
                <Button type="button" size="sm" variant="outline" asChild>
                  <a href={labelDocument.url} target="_blank" rel="noopener noreferrer">
                    <PrinterIcon data-icon="inline-start" />
                    {t('admin.orders.detail.fulfillments.print_label')}
                  </a>
                </Button>
              )}

              <Button type="button" size="sm" onClick={() => setFulfilling(true)}>
                <TruckIcon data-icon="inline-start" />
                {t('admin.orders.fulfill.action')}
              </Button>
            </div>
          )}

          {!shippable && labelDocument && (
            <div className="flex justify-end p-3 border-t">
              <Button type="button" size="sm" variant="outline" asChild>
                <a href={labelDocument.url} target="_blank" rel="noopener noreferrer">
                  <PrinterIcon data-icon="inline-start" />
                  {t('admin.orders.detail.fulfillments.print_label')}
                </a>
              </Button>
            </div>
          )}

          {deliverable && (
            <div className="flex justify-end gap-2 p-3 border-t">
              <Button
                type="button"
                size="sm"
                variant={trackable ? 'outline' : 'default'}
                disabled={markDelivered.isPending}
                onClick={() => markDelivered.mutate(fulfillment.id)}
              >
                <PackageCheckIcon data-icon="inline-start" />
                {t('admin.orders.detail.fulfillments.mark_delivered')}
              </Button>

              {trackable && (
                <Button type="button" size="sm" onClick={() => setTrackingOpen(true)}>
                  <PlusIcon data-icon="inline-start" />
                  {t('admin.orders.detail.fulfillments.add_tracking')}
                </Button>
              )}
            </div>
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

      {trackingOpen && (
        <FulfillmentTrackingDialog
          orderId={orderId}
          fulfillment={fulfillment}
          open={trackingOpen}
          onOpenChange={setTrackingOpen}
        />
      )}
    </div>
  )
}

/**
 * Units nobody has put into a fulfillment yet. Reads like a fulfillment group
 * so the eye can compare it against the real ones, minus the status and number
 * it does not have.
 */
function UnfulfilledGroup({ rows }: { rows: FulfillmentItemRow[] }) {
  const { t } = useTranslation()

  const totalUnits = rows.reduce((sum, row) => sum + row.quantity, 0)

  return (
    <div className="rounded-lg border p-4 flex flex-col gap-3">
      <div className="flex items-center gap-2">
        <PackageIcon className="size-4 text-muted-foreground" />
        <span className="text-sm font-medium">
          {t('admin.orders.detail.fulfillments.unfulfilled', { count: totalUnits })}
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
            {unfulfilled.length > 0 && <UnfulfilledGroup rows={unfulfilled} />}
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
