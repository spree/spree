import { fulfillmentItemRows } from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
  CardAction,
  CardContent,
  CardFooter,
  CardHeader,
  CardTitle,
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
  FulfillmentItemList,
  FulfillmentPanel,
  StatusBadge,
  useConfirm,
} from '@spree/dashboard-ui'
import {
  EllipsisVerticalIcon,
  PencilIcon,
  PlusIcon,
  PrinterIcon,
  SplitIcon,
  TagIcon,
  TruckIcon,
  XCircleIcon,
} from '@spree/dashboard-ui/icons'
import type { Delivery, Fulfillment, Order } from '@spree/seller-sdk'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useFulfillmentActions } from '../../hooks/use-fulfillments'
import { printPackingSlip } from '../../lib/packing-slip'
import { FulfillmentDeliveries } from './fulfillment-deliveries'
import { FulfillmentDeliveryDialog } from './fulfillment-delivery-dialog'
import { FulfillmentEditDialog } from './fulfillment-edit-dialog'
import { FulfillmentFulfillForm } from './fulfillment-fulfill-form'
import { FulfillmentLabelUploadDialog } from './fulfillment-label-upload-dialog'
import { FulfillmentSplitDialog } from './fulfillment-split-dialog'
import { ShippingLabelRow } from './shipping-label-row'

// A parcel that has not gone out is the only one still to ship or cancel.
// Reading these off "not unfulfilled" once badged a canceled parcel as a
// success.
const CAN_SHIP = ['unfulfilled']
const CAN_CANCEL = ['unfulfilled']

/** Every parcel owed on this order, and what the seller can do with each. */
export function FulfillmentsCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  const fulfillments = order.fulfillments ?? []

  return (
    <Card>
      <CardHeader>
        <CardTitle>
          <TruckIcon className="size-4" />
          {t('orders.fulfillments.title')}
          {fulfillments.length > 0 && <Badge variant="outline">{fulfillments.length}</Badge>}
        </CardTitle>
        <CardAction>
          {order.fulfillment_status && (
            <StatusBadge
              status={order.fulfillment_status}
              label={t(`orders.fulfillment_statuses.${order.fulfillment_status}`, {
                defaultValue: order.fulfillment_status,
              })}
            />
          )}
        </CardAction>
      </CardHeader>

      {fulfillments.length === 0 ? (
        <CardContent>
          <p className="py-8 text-center text-muted-foreground">{t('orders.fulfillments.empty')}</p>
        </CardContent>
      ) : (
        <CardContent className="flex flex-col gap-4">
          {fulfillments.map((fulfillment) => (
            <FulfillmentRow key={fulfillment.id} order={order} fulfillment={fulfillment} />
          ))}
        </CardContent>
      )}
    </Card>
  )
}

function FulfillmentRow({ order, fulfillment }: { order: Order; fulfillment: Fulfillment }) {
  const orderId = order.id
  const { t } = useTranslation()
  const confirm = useConfirm()
  const { cancel } = useFulfillmentActions(orderId)

  const [fulfilling, setFulfilling] = useState(false)
  const [deliveryOpen, setDeliveryOpen] = useState(false)
  const [editingDelivery, setEditingDelivery] = useState<Delivery | undefined>()
  const [labelOpen, setLabelOpen] = useState(false)
  const [editOpen, setEditOpen] = useState(false)
  const [splitOpen, setSplitOpen] = useState(false)

  const status = fulfillment.status ?? ''
  const shippable = CAN_SHIP.includes(status)
  const cancelable = CAN_CANCEL.includes(status)
  const splittable = shippable && (fulfillment.fulfillment_items?.length ?? 0) > 0
  const deliveries = fulfillment.deliveries ?? []
  // At most one label binds a parcel: the workflows refuse a second while one
  // is active, and a refunded one stays as history.
  const activeLabel = (fulfillment.labels ?? []).find((label) => label.status !== 'refunded')
  // A seller buys postage elsewhere and uploads it, so the slot is offered
  // only while the parcel has no label and has not gone out.
  const canUploadLabel = shippable && !activeLabel

  async function handleCancel() {
    const ok = await confirm({
      title: t('orders.fulfillments.cancel_title'),
      message: t('orders.fulfillments.cancel_message'),
      variant: 'destructive',
      confirmLabel: t('orders.fulfillments.cancel'),
    })
    if (!ok) return
    cancel.mutate(fulfillment.id)
  }

  return (
    <FulfillmentPanel
      status={status}
      statusLabel={t(`orders.fulfillment_statuses.${status}`, { defaultValue: status })}
      location={fulfillment.stock_location_name}
      actions={
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="ghost" size="icon-xs">
              <EllipsisVerticalIcon className="size-4" />
              <span className="sr-only">{t('admin.actions.actions_menu')}</span>
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            {shippable && (
              <DropdownMenuItem onClick={() => setEditOpen(true)}>
                <PencilIcon className="size-4" />
                {t('admin.actions.edit')}
              </DropdownMenuItem>
            )}
            {splittable && (
              <DropdownMenuItem onClick={() => setSplitOpen(true)}>
                <SplitIcon className="size-4" />
                {t('orders.fulfillments.split')}
              </DropdownMenuItem>
            )}
            <DropdownMenuItem onClick={() => printPackingSlip(order, fulfillment, t)}>
              <PrinterIcon className="size-4" />
              {t('orders.fulfillments.print_packing_slip')}
            </DropdownMenuItem>
            <DropdownMenuItem
              onClick={() => {
                setEditingDelivery(undefined)
                setDeliveryOpen(true)
              }}
            >
              <TruckIcon className="size-4" />
              {t('orders.fulfillments.add_delivery')}
            </DropdownMenuItem>
            {canUploadLabel && (
              <DropdownMenuItem onClick={() => setLabelOpen(true)}>
                <TagIcon className="size-4" />
                {t('orders.fulfillments.upload_label')}
              </DropdownMenuItem>
            )}
            {cancelable && (
              <>
                <DropdownMenuSeparator />
                <DropdownMenuItem
                  variant="destructive"
                  disabled={cancel.isPending}
                  onClick={handleCancel}
                >
                  <XCircleIcon className="size-4" />
                  {t('orders.fulfillments.cancel')}
                </DropdownMenuItem>
              </>
            )}
          </DropdownMenuContent>
        </DropdownMenu>
      }
    >
      {fulfillment.delivery_method_name && (
        <CardContent className="flex items-center justify-between border-border-subtle border-b py-3 text-sm">
          <span className="text-muted-foreground">{fulfillment.delivery_method_name}</span>
        </CardContent>
      )}

      {activeLabel && !fulfilling && (
        <ShippingLabelRow orderId={orderId} fulfillmentId={fulfillment.id} label={activeLabel} />
      )}

      <FulfillmentDeliveries
        orderId={orderId}
        fulfillmentId={fulfillment.id}
        deliveries={deliveries}
        onEdit={(delivery) => {
          setEditingDelivery(delivery)
          setDeliveryOpen(true)
        }}
      />

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
              <Button type="button" size="sm" onClick={() => setFulfilling(true)}>
                <TruckIcon data-icon="inline-start" />
                {t('orders.fulfill')}
              </Button>
            </CardFooter>
          )}

          {!shippable && deliveries.length === 0 && (
            <CardFooter className="justify-end gap-2 py-3">
              <Button
                type="button"
                size="sm"
                variant="outline"
                onClick={() => {
                  setEditingDelivery(undefined)
                  setDeliveryOpen(true)
                }}
              >
                <PlusIcon data-icon="inline-start" />
                {t('orders.fulfillments.add_tracking')}
              </Button>
            </CardFooter>
          )}
        </>
      )}

      {/* Mounted only while open, so each form seeds from the parcel as it is
          now. Left mounted, their defaults froze at first render — and after
          shipping, an edit would open empty and save that emptiness over a
          real number. */}
      {deliveryOpen && (
        <FulfillmentDeliveryDialog
          orderId={orderId}
          fulfillmentId={fulfillment.id}
          delivery={editingDelivery}
          open
          onOpenChange={(next) => {
            setDeliveryOpen(next)
            if (!next) setEditingDelivery(undefined)
          }}
        />
      )}
      {editOpen && (
        <FulfillmentEditDialog
          orderId={orderId}
          fulfillment={fulfillment}
          open
          onOpenChange={setEditOpen}
        />
      )}
      {labelOpen && (
        <FulfillmentLabelUploadDialog
          orderId={orderId}
          fulfillmentId={fulfillment.id}
          currency={order.currency}
          open
          onOpenChange={setLabelOpen}
        />
      )}
      {splittable && (
        <FulfillmentSplitDialog
          orderId={orderId}
          fulfillment={fulfillment}
          open={splitOpen}
          onOpenChange={setSplitOpen}
        />
      )}
    </FulfillmentPanel>
  )
}
