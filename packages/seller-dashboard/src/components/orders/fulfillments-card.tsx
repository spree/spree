import {
  Button,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
  StatusBadge,
  useConfirm,
} from '@spree/dashboard-ui'
import {
  EllipsisVerticalIcon,
  MapPinIcon,
  PencilIcon,
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
import { unitLabel } from './line-label'
import { ShippingLabelRow } from './shipping-label-row'

// A parcel that has not gone out is the only one still to ship or cancel;
// one that has is the only one that can be confirmed delivered. Reading
// these off "not unfulfilled" once badged a canceled parcel as a success.
const CAN_SHIP = ['unfulfilled']
const CAN_CANCEL = ['unfulfilled']

/** Every parcel owed on this order, and what the seller can do with each. */
export function FulfillmentsCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  const fulfillments = order.fulfillments ?? []

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <TruckIcon className="size-4" />
          {t('orders.fulfillments.title')}
        </CardTitle>
        {order.fulfillment_status && (
          <CardAction>
            <StatusBadge
              status={order.fulfillment_status}
              label={t(`orders.fulfillment_statuses.${order.fulfillment_status}`)}
            />
          </CardAction>
        )}
      </CardHeader>

      <CardContent className="flex flex-col gap-3">
        {fulfillments.length === 0 ? (
          <p className="text-muted-foreground text-sm">{t('orders.fulfillments.empty')}</p>
        ) : (
          fulfillments.map((fulfillment) => (
            <FulfillmentRow
              key={fulfillment.id}
              order={order}
              currency={order.currency}
              fulfillment={fulfillment}
            />
          ))
        )}
      </CardContent>
    </Card>
  )
}

function FulfillmentRow({
  order,
  currency,
  fulfillment,
}: {
  order: Order
  currency: string
  fulfillment: Fulfillment
}) {
  const orderId = order.id
  const { t } = useTranslation()
  const confirm = useConfirm()
  const { cancel } = useFulfillmentActions(orderId)

  const [shipping, setShipping] = useState(false)
  const [deliveryOpen, setDeliveryOpen] = useState(false)
  const [editingDelivery, setEditingDelivery] = useState<Delivery | undefined>()
  const [labelOpen, setLabelOpen] = useState(false)
  const [editOpen, setEditOpen] = useState(false)
  const [splitOpen, setSplitOpen] = useState(false)

  const status = fulfillment.status ?? ''
  const shippable = CAN_SHIP.includes(status)
  const cancelable = CAN_CANCEL.includes(status)
  const splittable = shippable && (fulfillment.fulfillment_items?.length ?? 0) > 0

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
    <Card variant="nested">
      <CardHeader>
        <CardTitle className="text-sm">{fulfillment.number}</CardTitle>
        <CardAction className="flex items-center gap-2">
          <StatusBadge
            status={status}
            label={t(`orders.fulfillment_statuses.${status}`, { defaultValue: status })}
          />
          <DropdownMenu>
            <DropdownMenuTrigger
              render={
                <Button variant="ghost" size="icon" aria-label={t('common.actions')}>
                  <EllipsisVerticalIcon className="size-4" />
                </Button>
              }
            />
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
              <DropdownMenuItem onClick={() => setLabelOpen(true)}>
                <TagIcon className="size-4" />
                {t('orders.fulfillments.upload_label')}
              </DropdownMenuItem>
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
        </CardAction>
      </CardHeader>

      {(fulfillment.labels ?? []).map((label) => (
        <ShippingLabelRow
          key={label.id}
          orderId={orderId}
          fulfillmentId={fulfillment.id}
          label={label}
        />
      ))}

      <FulfillmentDeliveries
        orderId={orderId}
        fulfillmentId={fulfillment.id}
        deliveries={fulfillment.deliveries ?? []}
        onEdit={(delivery) => {
          setEditingDelivery(delivery)
          setDeliveryOpen(true)
        }}
      />

      <CardContent className="flex flex-col gap-3">
        {fulfillment.stock_location_name && (
          <p className="flex items-center gap-1.5 text-muted-foreground text-sm">
            <MapPinIcon className="size-3.5 shrink-0" />
            {t('orders.ships_from', { name: fulfillment.stock_location_name })}
          </p>
        )}

        {fulfillment.delivery_method_name && (
          <p className="text-muted-foreground text-sm">{fulfillment.delivery_method_name}</p>
        )}

        {shipping ? (
          <FulfillmentFulfillForm
            orderId={orderId}
            fulfillment={fulfillment}
            onDone={() => setShipping(false)}
          />
        ) : (
          <>
            {fulfillment.fulfillment_items?.map((item) => (
              <div key={item.id} className="flex items-center justify-between gap-3 text-sm">
                <span className="truncate">{unitLabel(item)}</span>
                <span className="shrink-0 text-muted-foreground">× {item.quantity}</span>
              </div>
            ))}

            {shippable && (
              <div className="flex justify-end">
                <Button type="button" onClick={() => setShipping(true)}>
                  {t('orders.fulfill')}
                </Button>
              </div>
            )}
          </>
        )}
      </CardContent>

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
          currency={currency}
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
    </Card>
  )
}
