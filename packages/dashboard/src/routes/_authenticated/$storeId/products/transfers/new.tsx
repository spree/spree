import { PageHeader } from '@spree/dashboard-core'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import {
  EMPTY_STOCK_TRANSFER,
  StockTransferForm,
  type StockTransferFormValues,
} from '../../../../../components/spree/stock-transfer-form'
import { useCreateStockTransfer } from '../../../../../hooks/use-stock-transfers'

export const Route = createFileRoute('/_authenticated/$storeId/products/transfers/new')({
  component: NewStockTransferPage,
})

function NewStockTransferPage() {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const navigate = useNavigate()
  const createMutation = useCreateStockTransfer()

  async function handleSubmit(values: StockTransferFormValues) {
    // The hook toasts the refusal; there is nowhere inline to put it on a
    // page that has no form errors, and navigating would hide it.
    const transfer = await createMutation
      .mutateAsync({
        source_location_id: values.sourceId,
        destination_location_id: values.destinationId,
        reference: values.reference.trim() || undefined,
        notes: values.notes.trim() || undefined,
        items: values.lines.map((line) => ({
          variant_id: line.variant.id,
          quantity_shipped: line.quantity,
        })),
      })
      .catch(() => undefined)
    if (!transfer) return

    navigate({
      to: '/$storeId/products/transfers/$transferId',
      params: { storeId, transferId: transfer.id },
    })
  }

  return (
    <div className="mx-auto flex w-full max-w-3xl flex-col gap-4 p-4">
      <PageHeader title={t('admin.stock_transfers.new_title')} backTo="products/transfers" />

      <StockTransferForm
        initial={EMPTY_STOCK_TRANSFER}
        submitLabel={t('admin.stock_transfers.actions.create_draft')}
        pendingLabel={t('admin.actions.creating')}
        pending={createMutation.isPending}
        onSubmit={handleSubmit}
        onCancel={() => navigate({ to: '/$storeId/products/transfers', params: { storeId } })}
      />
    </div>
  )
}
