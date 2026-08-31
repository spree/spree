import type { Order } from '@spree/admin-sdk'
import {
  adminClient,
  downloadFromApi,
  EMPTY_FILE_UPLOAD_VALUE,
  FileUploadField,
  type FileUploadValue,
  getApiClient,
  useAuth,
} from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  Input,
  toastManager,
} from '@spree/dashboard-ui'
import { DownloadIcon, FileTextIcon, PencilIcon } from 'lucide-react'
import { type FormEvent, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useOrderMutation } from '../../../hooks/use-order'

/** What a purchase order plausibly arrives as — mirrors the server allowlist. */
const PO_DOCUMENT_ACCEPT =
  'application/pdf,image/jpeg,image/png,image/heic,image/webp,application/msword,application/vnd.openxmlformats-officedocument.wordprocessingml.document'

interface UpdateParams {
  po_number: string
  po_document?: string | null
}

/**
 * The buyer's own purchase-order reference and the document behind it.
 *
 * Editable after placement by design: correcting a reference the buyer forgot,
 * or attaching the PO they emailed after the fact, is a plain attribute write
 * rather than a change to what was sold, so it never goes through the
 * order-edit flow.
 */
export function OrderPurchaseOrderCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  const { token } = useAuth()
  const orderId = order.id

  const [editing, setEditing] = useState(false)
  const [document, setDocument] = useState<FileUploadValue>(EMPTY_FILE_UPLOAD_VALUE)
  // The signed id does not exist until the upload resolves, so saving during
  // one would silently drop the file.
  const [uploading, setUploading] = useState(false)

  const mutation = useOrderMutation(orderId, (params: UpdateParams) =>
    adminClient.orders.update(orderId, params),
  )

  function stopEditing() {
    setEditing(false)
    setDocument(EMPTY_FILE_UPLOAD_VALUE)
  }

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const data = new FormData(event.currentTarget)

    const params: UpdateParams = { po_number: data.get('po_number') as string }
    // Three states: a new upload sends its signed id, an explicit removal
    // sends null, and an untouched field is omitted so the save leaves
    // whatever is attached alone.
    if (document.signedId) params.po_document = document.signedId
    else if (document.cleared) params.po_document = null

    mutation.mutate(params, { onSuccess: stopEditing })
  }

  // Streamed through the admin endpoint rather than a public blob URL, so the
  // request has to carry the admin's credentials — and the tenant header the
  // SDK adds to every other request, or the download resolves against the
  // default store.
  async function handleDownload() {
    if (!order.po_document_url) return

    try {
      await downloadFromApi(
        token,
        order.po_document_url,
        order.po_document_filename ?? 'purchase-order',
        getApiClient().downloadHeaders?.() ?? {},
      )
    } catch (error) {
      // The fetch rejects on any non-success response, and a click handler
      // that swallows it leaves the merchant staring at a button that did
      // nothing.
      toastManager.add({
        type: 'error',
        title: t('admin.orders.detail.purchase_order.download_failed'),
        description: error instanceof Error ? error.message : String(error),
      })
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.orders.detail.purchase_order.title')}</CardTitle>
        <CardAction>
          <Button
            variant="ghost"
            size="icon-sm"
            onClick={() => (editing ? stopEditing() : setEditing(true))}
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
            {/* Private storage: a purchase order carries the buyer's prices,
                terms and internal cost codes, and attaching a signed id never
                moves a blob between services. */}
            <FileUploadField
              private
              value={document}
              onChange={setDocument}
              accept={PO_DOCUMENT_ACCEPT}
              variant="file"
              icon={<FileTextIcon className="size-4" />}
              serverUrl={order.po_document_url}
              serverFilename={order.po_document_filename}
              label={t('admin.orders.detail.purchase_order.document')}
              help={t('admin.orders.detail.purchase_order.document_help')}
              onUploadingChange={setUploading}
            />
            <div className="flex justify-end gap-2">
              <Button type="button" variant="outline" size="sm" onClick={stopEditing}>
                {t('admin.actions.cancel')}
              </Button>
              <Button type="submit" size="sm" disabled={mutation.isPending || uploading}>
                {mutation.isPending ? t('admin.actions.saving') : t('admin.actions.save')}
              </Button>
            </div>
          </form>
        ) : (
          <>
            {order.po_number ? (
              <p className="text-sm font-medium tabular-nums">{order.po_number}</p>
            ) : (
              <p className="text-sm text-muted-foreground">{t('admin.common.none')}</p>
            )}

            {order.po_document_url && (
              <Button
                variant="outline"
                size="sm"
                className="justify-start"
                onClick={handleDownload}
              >
                <DownloadIcon className="size-4 shrink-0" />
                <span className="truncate">
                  {order.po_document_filename ?? t('admin.orders.detail.purchase_order.document')}
                </span>
              </Button>
            )}
          </>
        )}
      </CardContent>
    </Card>
  )
}
