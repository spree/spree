import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import {
  EMPTY_STOCK_TRANSFER,
  StockTransferForm,
  type StockTransferFormValues,
} from '../../../../components/spree/stock-transfer-form'
import { useCreateStockTransfer } from '../../../../hooks/use-stock-transfers'
import { prefilledLines, prefilledVariantSchema } from '../../../../lib/prefilled-variant'

export const Route = createFileRoute('/_authenticated/$storeId/transfers/new')({
  validateSearch: prefilledVariantSchema,
  component: NewStockTransferPage,
})

function NewStockTransferPage() {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const search = Route.useSearch()
  const navigate = useNavigate()
  const createMutation = useCreateStockTransfer()

  // Arriving from an Inventory row: that SKU is on the transfer, and the
  // warehouse it is short at is where it is going.
  const initial: StockTransferFormValues = {
    ...EMPTY_STOCK_TRANSFER,
    destinationId: search.stock_location_id ?? '',
    lines: prefilledLines(search, false),
  }

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
      to: '/$storeId/transfers/$transferId',
      params: { storeId, transferId: transfer.id },
    })
  }

  return (
    <StockTransferForm
      initial={initial}
      title={t('admin.stock_transfers.new_title')}
      backTo="transfers"
      submitLabel={t('admin.stock_transfers.actions.create_draft')}
      pendingLabel={t('admin.actions.creating')}
      pending={createMutation.isPending}
      onSubmit={handleSubmit}
      onCancel={() => navigate({ to: '/$storeId/transfers', params: { storeId } })}
    />
  )
}
