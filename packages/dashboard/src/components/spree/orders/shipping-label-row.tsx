import type { ShippingLabel } from '@spree/admin-sdk'
import { downloadFromApi, getApiClient, useAuth } from '@spree/dashboard-core'
import {
  Badge,
  Button,
  CardContent,
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
  toastManager,
  useConfirm,
} from '@spree/dashboard-ui'
import { EllipsisVerticalIcon, PrinterIcon, ReceiptIcon, TrashIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'

/**
 * The label bound to a parcel: what it cost, how to print it, and how to give
 * it back. A purchased label is refunded through the carrier; an uploaded one
 * has nothing to refund, so it is deleted instead.
 *
 * Owner-agnostic on purpose — an outbound parcel and a return's inbound one
 * are the same record with the same actions, so the caller passes the
 * mutations for whichever owns this label.
 */
export function ShippingLabelRow({
  label,
  onRefund,
  onDelete,
  isRefunding = false,
}: {
  label: ShippingLabel
  onRefund: () => void
  onDelete: () => void
  isRefunding?: boolean
}) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const { token } = useAuth()

  // Mirrors Spree::ShippingLabel#refundable? — a label the carrier is still
  // deciding on stays askable, because re-filing is the only way to re-drive a
  // refund whose confirmation never arrived.
  const refundable = label.source === 'purchased' && label.status !== 'refunded'
  // A refund already filed and not yet settled: the same action re-files it.
  const refundPending = label.status === 'refund_requested'
  const refundLabelKey = refundPending
    ? 'admin.orders.detail.fulfillments.retry_refund_label'
    : 'admin.orders.detail.fulfillments.refund_label'
  const deletable = label.source === 'uploaded'

  async function print() {
    if (!label.download_url) return

    // A rejected download inside a click handler is otherwise unhandled, so
    // the file silently never arrives.
    try {
      await downloadFromApi(
        token,
        label.download_url,
        `${label.tracking_number ?? 'label'}.${label.format ?? 'pdf'}`,
        getApiClient().downloadHeaders?.() ?? {},
      )
    } catch {
      // Deliberately not the thrown message: `downloadFromApi` reports the
      // transport in English ("Download failed: 404"), which would land
      // untranslated in a localized panel and tells the merchant nothing they
      // can act on.
      toastManager.add({ type: 'error', title: t('admin.errors.label_download_failed') })
    }
  }

  return (
    <CardContent className="flex flex-wrap items-center justify-between gap-2 border-b border-border-subtle py-3 text-sm">
      <div className="flex flex-wrap items-center gap-2">
        <ReceiptIcon className="size-4 text-muted-foreground" />
        <span className="text-muted-foreground">
          {t('admin.orders.detail.fulfillments.label_title')}
        </span>
        {label.source === 'uploaded' && (
          <Badge variant="secondary">{t('admin.orders.detail.fulfillments.label_uploaded')}</Badge>
        )}
        {label.status === 'refund_requested' && (
          <Badge variant="secondary">
            {t('admin.orders.detail.fulfillments.label_refund_requested')}
          </Badge>
        )}
        {label.status === 'refunded' && (
          <Badge variant="secondary">{t('admin.orders.detail.fulfillments.label_refunded')}</Badge>
        )}
        {/* What the merchant paid the carrier — accounting data, never the
            shopper's shipping charge. */}
        <span className="text-muted-foreground">
          {t('admin.orders.detail.fulfillments.label_cost')}: {label.display_cost}
        </span>
      </div>

      <div className="flex items-center gap-2">
        {label.download_url && (
          <Button type="button" size="sm" variant="outline" onClick={print}>
            <PrinterIcon data-icon="inline-start" />
            {t('admin.orders.detail.fulfillments.print_label')}
          </Button>
        )}

        {refundable && (
          <Button
            type="button"
            size="sm"
            variant="outline"
            disabled={isRefunding}
            onClick={async () => {
              if (
                await confirm({
                  message: t('admin.orders.detail.fulfillments.confirm_refund_label'),
                  variant: 'destructive',
                  confirmLabel: t(refundLabelKey),
                })
              ) {
                onRefund()
              }
            }}
          >
            {t(refundLabelKey)}
          </Button>
        )}

        {deletable && (
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button type="button" variant="ghost" size="icon-xs">
                <EllipsisVerticalIcon className="size-4" />
                <span className="sr-only">{t('admin.actions.actions_menu')}</span>
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuItem
                variant="destructive"
                onClick={async () => {
                  if (
                    await confirm({
                      message: t('admin.orders.detail.fulfillments.confirm_delete_label'),
                      variant: 'destructive',
                      confirmLabel: t('admin.actions.delete'),
                    })
                  ) {
                    onDelete()
                  }
                }}
              >
                <TrashIcon className="size-4" />
                {t('admin.orders.detail.fulfillments.delete_label')}
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        )}
      </div>
    </CardContent>
  )
}
