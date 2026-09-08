import { PageHeader } from '@spree/dashboard-core'
import { Alert, AlertDescription } from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import {
  StockTransferForm,
  type StockTransferFormValues,
} from '../../../../../../components/spree/stock-transfer-form'
import {
  useStockTransfer,
  useUpdateStockTransfer,
} from '../../../../../../hooks/use-stock-transfers'

export const Route = createFileRoute(
  '/_authenticated/$storeId/products/transfers/$transferId/edit',
)({ component: EditStockTransferPage })

function EditStockTransferPage() {
  const { t } = useTranslation()
  const { storeId, transferId } = Route.useParams()
  const navigate = useNavigate()
  const { data: transfer, isLoading } = useStockTransfer(transferId)
  const updateMutation = useUpdateStockTransfer(transferId)

  const backToTransfer = () =>
    navigate({ to: '/$storeId/products/transfers/$transferId', params: { storeId, transferId } })

  if (isLoading || !transfer) {
    return <div className="p-4 text-muted-foreground text-sm">{t('admin.common.loading')}</div>
  }

  // The endpoint refuses the write past draft, so the screen says so rather
  // than offering a form whose Save cannot succeed. Reachable by URL even
  // though the header hides the button once the transfer is packed.
  if (!transfer.editable) {
    return (
      <div className="mx-auto flex w-full max-w-3xl flex-col gap-4 p-4">
        <PageHeader
          title={t('admin.stock_transfers.edit_title', { number: transfer.number })}
          backTo={`products/transfers/${transferId}`}
        />
        <Alert>
          <AlertDescription>{t('admin.stock_transfers.errors.not_editable')}</AlertDescription>
        </Alert>
      </div>
    )
  }

  async function handleSubmit(values: StockTransferFormValues) {
    const saved = await updateMutation
      .mutateAsync({
        source_location_id: values.sourceId,
        destination_location_id: values.destinationId,
        // Cleared rather than omitted: an emptied field has to survive the
        // round trip, and omitting it would leave the old value in place.
        reference: values.reference.trim() || null,
        notes: values.notes.trim() || null,
        items: values.lines.map((line) => ({
          variant_id: line.variant.id,
          quantity_shipped: line.quantity,
        })),
      })
      .catch(() => undefined)
    if (!saved) return

    backToTransfer()
  }

  return (
    <div className="mx-auto flex w-full max-w-3xl flex-col gap-4 p-4">
      <PageHeader
        title={t('admin.stock_transfers.edit_title', { number: transfer.number })}
        backTo={`products/transfers/${transferId}`}
      />

      <StockTransferForm
        initial={{
          sourceId: transfer.source_location_id ?? '',
          destinationId: transfer.destination_location_id ?? '',
          reference: transfer.reference ?? '',
          notes: transfer.notes ?? '',
          // The saved lines carry the same four facts a search result does,
          // under their own names.
          lines: (transfer.items ?? []).map((item) => ({
            variant: {
              id: item.variant_id ?? '',
              sku: item.variant_sku,
              product_name: item.variant_name,
              thumbnail_url: item.thumbnail_url,
            },
            quantity: item.quantity_shipped,
          })),
        }}
        submitLabel={t('admin.actions.save')}
        pendingLabel={t('admin.actions.saving')}
        pending={updateMutation.isPending}
        onSubmit={handleSubmit}
        onCancel={backToTransfer}
      />
    </div>
  )
}
