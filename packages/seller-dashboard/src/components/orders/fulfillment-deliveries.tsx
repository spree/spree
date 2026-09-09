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
import { EllipsisVerticalIcon, PencilIcon, TrashIcon } from '@spree/dashboard-ui/icons'
import type { Delivery } from '@spree/seller-sdk'
import { useTranslation } from 'react-i18next'
import { useFulfillmentActions } from '../../hooks/use-fulfillments'

/**
 * The tracked consignments of one parcel.
 *
 * A parcel usually travels as one, but three boxes or a pallet under a freight
 * PRO number are the same shape — each with its own tracking number and its
 * own carrier status. Confirming arrival is not here: that a parcel landed is
 * the buyer's word, not the sender's, so it stays with the operator.
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
  const { deleteDelivery } = useFulfillmentActions(orderId)

  if (deliveries.length === 0) return null

  async function handleDelete(delivery: Delivery) {
    const ok = await confirm({
      message: t('orders.fulfillments.confirm_delete_delivery'),
      variant: 'destructive',
      confirmLabel: t('common.delete'),
    })
    if (!ok) return
    deleteDelivery.mutate({ fulfillmentId, deliveryId: delivery.id })
  }

  return (
    <CardContent className="flex flex-col gap-2 border-border-subtle border-b py-3 text-sm">
      {deliveries.map((delivery) => (
        <div key={delivery.id} className="flex flex-wrap items-center justify-between gap-2">
          <div className="flex min-w-0 flex-wrap items-center gap-2">
            <span className="text-muted-foreground">
              {delivery.carrier_name ?? t('orders.tracking_label')}:
            </span>
            {delivery.tracking_url ? (
              <a
                href={delivery.tracking_url}
                target="_blank"
                rel="noopener noreferrer"
                className="truncate underline"
              >
                {delivery.tracking_number}
              </a>
            ) : (
              <span className="truncate">{delivery.tracking_number}</span>
            )}
            <StatusBadge
              status={delivery.status}
              label={t(`orders.fulfillments.carrier_status_${delivery.status}`, {
                defaultValue: delivery.status,
              })}
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
              <DropdownMenuItem onClick={() => onEdit(delivery)}>
                <PencilIcon className="size-4" />
                {t('common.edit')}
              </DropdownMenuItem>

              {/* Two consignments are not removable: one a label minted, since
                  the label records what was bought, and one that arrived,
                  since its arrival is what the returns window counts from. The
                  server refuses both; this keeps the menu honest. */}
              {!delivery.shipping_label_id && delivery.status !== 'delivered' && (
                <>
                  <DropdownMenuSeparator />
                  <DropdownMenuItem
                    variant="destructive"
                    disabled={deleteDelivery.isPending}
                    onClick={() => handleDelete(delivery)}
                  >
                    <TrashIcon className="size-4" />
                    {t('common.delete')}
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
