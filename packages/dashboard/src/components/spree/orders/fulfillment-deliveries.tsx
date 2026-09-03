import type { Delivery } from '@spree/admin-sdk'
import { Badge, Button, CardContent, useConfirm } from '@spree/dashboard-ui'
import { PackageCheckIcon, PencilIcon, TrashIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'
import { useFulfillmentActions } from '../../../hooks/use-fulfillments'

/** How far along the carrier says each consignment is. */
const STATUS_VARIANT: Record<string, 'secondary' | 'default' | 'destructive'> = {
  delivered: 'default',
  failure: 'destructive',
  return_to_sender: 'destructive',
}

/**
 * The tracked consignments of one parcel. A parcel usually has one, but three
 * boxes or a freight PRO number covering a pallet are the same shape, and each
 * travels on its own carrier status.
 */
export function FulfillmentDeliveries({
  orderId,
  fulfillmentId,
  deliveries,
  onEdit,
  canMarkDelivered,
}: {
  orderId: string
  fulfillmentId: string
  deliveries: Delivery[]
  onEdit: (delivery: Delivery) => void
  canMarkDelivered: boolean
}) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const { deleteDelivery, markDeliveryDelivered } = useFulfillmentActions(orderId)

  if (deliveries.length === 0) return null

  return (
    <CardContent className="space-y-2 border-b border-border-subtle py-3 text-sm">
      {deliveries.map((delivery) => (
        <div key={delivery.id} className="flex flex-wrap items-center justify-between gap-2">
          <div className="flex min-w-0 flex-wrap items-center gap-2">
            <span className="text-muted-foreground">
              {delivery.carrier_name ?? t('admin.orders.detail.tracking.prefix')}:
            </span>
            {delivery.tracking_url ? (
              <a
                href={delivery.tracking_url}
                target="_blank"
                rel="noopener noreferrer"
                className="truncate text-blue-600 hover:underline"
              >
                {delivery.tracking_number}
              </a>
            ) : (
              <span className="truncate">{delivery.tracking_number}</span>
            )}
            <Badge variant={STATUS_VARIANT[delivery.status] ?? 'secondary'}>
              {t(`admin.orders.detail.fulfillments.carrier_status_${delivery.status}`)}
            </Badge>
          </div>

          <div className="flex items-center gap-1">
            {canMarkDelivered && delivery.status !== 'delivered' && (
              <Button
                type="button"
                size="icon-xs"
                variant="ghost"
                disabled={markDeliveryDelivered.isPending}
                onClick={() =>
                  markDeliveryDelivered.mutate({ fulfillmentId, deliveryId: delivery.id })
                }
              >
                <PackageCheckIcon className="size-4" />
                <span className="sr-only">
                  {t('admin.orders.detail.fulfillments.mark_delivery_delivered')}
                </span>
              </Button>
            )}

            <Button type="button" size="icon-xs" variant="ghost" onClick={() => onEdit(delivery)}>
              <PencilIcon className="size-4" />
              <span className="sr-only">{t('admin.actions.edit')}</span>
            </Button>

            {/* A consignment a label minted is not removable on its own — the
                label is the record of what was bought, so the way out is
                refunding it. The server refuses too; this keeps the button
                honest. */}
            {!delivery.shipping_label_id && (
              <Button
                type="button"
                size="icon-xs"
                variant="ghost"
                onClick={async () => {
                  if (
                    await confirm({
                      message: t('admin.orders.detail.fulfillments.confirm_delete_delivery'),
                      variant: 'destructive',
                      confirmLabel: t('admin.actions.delete'),
                    })
                  ) {
                    deleteDelivery.mutate({ fulfillmentId, deliveryId: delivery.id })
                  }
                }}
              >
                <TrashIcon className="size-4" />
                <span className="sr-only">{t('admin.actions.delete')}</span>
              </Button>
            )}
          </div>
        </div>
      ))}
    </CardContent>
  )
}
