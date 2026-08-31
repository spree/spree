import type { Order } from '@spree/admin-sdk'
import { adminClient, downloadFromApi, getApiClient, useAuth } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  Input,
} from '@spree/dashboard-ui'
import { DownloadIcon, PencilIcon } from 'lucide-react'
import { type FormEvent, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useOrderMutation } from '../../../hooks/use-order'

/**
 * The buyer's own purchase-order reference and the document behind it.
 *
 * Editable after placement by design: correcting a reference the buyer forgot
 * is a plain attribute write, not a change to what was sold, so it never goes
 * through the order-edit flow.
 */
export function OrderPurchaseOrderCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  const { token } = useAuth()
  const orderId = order.id

  const [editing, setEditing] = useState(false)
  const mutation = useOrderMutation(orderId, (params: { po_number: string }) =>
    adminClient.orders.update(orderId, params),
  )

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const data = new FormData(event.currentTarget)
    mutation.mutate(
      { po_number: data.get('po_number') as string },
      { onSuccess: () => setEditing(false) },
    )
  }

  // Streamed through the admin endpoint rather than a public blob URL, so the
  // request has to carry the admin's credentials — and the tenant header the
  // SDK adds to every other request, or the download resolves against the
  // default store.
  async function handleDownload() {
    if (!order.po_document_url) return

    await downloadFromApi(
      token,
      order.po_document_url,
      order.po_document_filename ?? 'purchase-order',
      getApiClient().downloadHeaders?.() ?? {},
    )
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.orders.detail.purchase_order.title')}</CardTitle>
        <CardAction>
          <Button
            variant="ghost"
            size="icon-sm"
            onClick={() => setEditing(!editing)}
            aria-label={t('admin.actions.edit')}
          >
            <PencilIcon className="size-4" />
          </Button>
        </CardAction>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        {editing ? (
          <form onSubmit={handleSubmit} className="flex flex-col gap-3">
            <Input
              name="po_number"
              defaultValue={order.po_number ?? ''}
              placeholder={t('admin.fields.order.po_number.placeholder')}
              aria-label={t('admin.fields.order.po_number.label')}
            />
            <div className="flex justify-end gap-2">
              <Button type="button" variant="outline" size="sm" onClick={() => setEditing(false)}>
                {t('admin.actions.cancel')}
              </Button>
              <Button type="submit" size="sm" disabled={mutation.isPending}>
                {mutation.isPending ? t('admin.actions.saving') : t('admin.actions.save')}
              </Button>
            </div>
          </form>
        ) : order.po_number ? (
          <p className="text-sm font-medium tabular-nums">{order.po_number}</p>
        ) : (
          <p className="text-sm text-muted-foreground">{t('admin.common.none')}</p>
        )}

        {order.po_document_url && (
          <Button variant="outline" size="sm" className="justify-start" onClick={handleDownload}>
            <DownloadIcon className="size-4 shrink-0" />
            <span className="truncate">
              {order.po_document_filename ?? t('admin.orders.detail.purchase_order.document')}
            </span>
          </Button>
        )}
      </CardContent>
    </Card>
  )
}
