import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import {
  EMPTY_PURCHASE_ORDER,
  PurchaseOrderForm,
  type PurchaseOrderFormValues,
} from '../../../../components/spree/purchase-order-form'
import { useCreatePurchaseOrder } from '../../../../hooks/use-purchase-orders'

export const Route = createFileRoute('/_authenticated/$storeId/purchase-orders/new')({
  component: NewPurchaseOrderPage,
})

function NewPurchaseOrderPage() {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const navigate = useNavigate()
  const createMutation = useCreatePurchaseOrder()

  async function handleSubmit(values: PurchaseOrderFormValues) {
    // The hook toasts the refusal; navigating would hide it.
    const purchaseOrder = await createMutation
      .mutateAsync({
        supplier_id: values.supplierId,
        destination_location_id: values.destinationId,
        currency: values.currency,
        expected_at: values.expectedAt,
        reference: values.reference.trim() || undefined,
        notes: values.notes.trim() || undefined,
        items: values.lines.map((line) => ({
          variant_id: line.variant.id,
          quantity_ordered: line.quantity,
          unit_cost: line.unitCost,
        })),
      })
      .catch(() => undefined)
    if (!purchaseOrder) return

    navigate({
      to: '/$storeId/purchase-orders/$purchaseOrderId',
      params: { storeId, purchaseOrderId: purchaseOrder.id },
    })
  }

  return (
    <PurchaseOrderForm
      initial={EMPTY_PURCHASE_ORDER}
      title={t('admin.purchase_orders.new_title')}
      backTo="purchase-orders"
      submitLabel={t('admin.purchase_orders.actions.create_draft')}
      pendingLabel={t('admin.actions.creating')}
      pending={createMutation.isPending}
      onSubmit={handleSubmit}
      onCancel={() => navigate({ to: '/$storeId/purchase-orders', params: { storeId } })}
    />
  )
}
