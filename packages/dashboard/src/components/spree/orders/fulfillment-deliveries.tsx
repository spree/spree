import type { Delivery } from '@spree/admin-sdk'
import {
  Button,
  CardContent,
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
  StatusBadge,
  useConfirm,
} from '@spree/dashboard-ui'
import { EllipsisVerticalIcon, PackageCheckIcon, PencilIcon, TrashIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'
import { useFulfillmentActions } from '../../../hooks/use-fulfillments'

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
}: {
  orderId: string
  fulfillmentId: string
  deliveries: Delivery[]
  onEdit: (delivery: Delivery) => void
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
            <StatusBadge
              status={delivery.status}
              label={t(`admin.orders.detail.fulfillments.carrier_status_${delivery.status}`)}
            />
          </div>

          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" size="icon-xs">
                <EllipsisVerticalIcon className="size-4" />
                <span className="sr-only">{t('admin.actions.actions_menu')}</span>
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              {delivery.status !== 'delivered' && (
                <DropdownMenuItem
                  disabled={markDeliveryDelivered.isPending}
                  onClick={() =>
                    markDeliveryDelivered.mutate({ fulfillmentId, deliveryId: delivery.id })
                  }
                >
                  <PackageCheckIcon className="size-4" />
                  {t('admin.orders.detail.fulfillments.mark_delivery_delivered')}
                </DropdownMenuItem>
              )}

              <DropdownMenuItem onClick={() => onEdit(delivery)}>
                <PencilIcon className="size-4" />
                {t('admin.actions.edit')}
              </DropdownMenuItem>

              {/* Two consignments are not removable: one a label minted, since
                  the label is the record of what was bought and refunding it
                  is the way out; and one that arrived, since its arrival is
                  what the returns window counts from. The server refuses
                  both; this keeps the menu honest. */}
              {!delivery.shipping_label_id && delivery.status !== 'delivered' && (
                <>
                  <DropdownMenuSeparator />
                  <DropdownMenuItem
                    variant="destructive"
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
                    {t('admin.actions.delete')}
                  </DropdownMenuItem>
                </>
              )}
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      ))}
    </CardContent>
  )
}
