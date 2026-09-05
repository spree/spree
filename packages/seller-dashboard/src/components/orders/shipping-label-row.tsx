import { downloadFromApi, getApiClient, useAuth } from '@spree/dashboard-core'
import {
  Badge,
  Button,
  CardContent,
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
  useConfirm,
} from '@spree/dashboard-ui'
import {
  EllipsisVerticalIcon,
  PrinterIcon,
  ReceiptTextIcon,
  TrashIcon,
} from '@spree/dashboard-ui/icons'
import type { ShippingLabel } from '@spree/seller-sdk'
import { useTranslation } from 'react-i18next'
import { useFulfillmentActions } from '../../hooks/use-fulfillments'

/**
 * The label bound to a parcel: what it cost and how to print it.
 *
 * Refunding is absent by design — postage bought through the marketplace's
 * carrier account is the operator's to reverse, and the endpoint refuses it.
 * Only a label the seller uploaded can be removed, since that is the only one
 * no carrier holds a record of.
 */
export function ShippingLabelRow({
  orderId,
  fulfillmentId,
  label,
}: {
  orderId: string
  fulfillmentId: string
  label: ShippingLabel
}) {
  const { t } = useTranslation()
  const { token } = useAuth()
  const confirm = useConfirm()
  const { deleteLabel } = useFulfillmentActions(orderId)

  const deletable = label.source === 'uploaded'

  async function print() {
    if (!label.download_url) return

    await downloadFromApi(
      token,
      label.download_url,
      `${label.tracking_number ?? 'label'}.${label.format ?? 'pdf'}`,
      getApiClient().downloadHeaders?.() ?? {},
    )
  }

  async function handleDelete() {
    const ok = await confirm({
      message: t('orders.fulfillments.confirm_delete_label'),
      variant: 'destructive',
      confirmLabel: t('common.delete'),
    })
    if (!ok) return
    deleteLabel.mutate({ fulfillmentId, labelId: label.id })
  }

  return (
    <CardContent className="flex flex-wrap items-center justify-between gap-2 border-border-subtle border-b py-3 text-sm">
      <div className="flex flex-wrap items-center gap-2">
        <ReceiptTextIcon className="size-4 text-muted-foreground" />
        <span className="text-muted-foreground">{t('orders.fulfillments.label_title')}</span>
        {label.source === 'uploaded' && (
          <Badge variant="secondary">{t('orders.fulfillments.label_uploaded')}</Badge>
        )}
        {label.display_cost && (
          <span className="text-muted-foreground">
            {t('orders.fulfillments.label_cost', { amount: label.display_cost })}
          </span>
        )}
      </div>

      <div className="flex items-center gap-2">
        {label.download_url && (
          <Button type="button" variant="outline" size="sm" onClick={print}>
            <PrinterIcon data-icon="inline-start" />
            {t('orders.fulfillments.print_label')}
          </Button>
        )}

        {deletable && (
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" size="icon-xs">
                <EllipsisVerticalIcon className="size-4" />
                <span className="sr-only">{t('admin.actions.actions_menu')}</span>
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuItem
                variant="destructive"
                disabled={deleteLabel.isPending}
                onClick={handleDelete}
              >
                <TrashIcon className="size-4" />
                {t('orders.fulfillments.delete_label')}
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        )}
      </div>
    </CardContent>
  )
}
