import { PageHeader } from '@spree/dashboard-core'
import { Alert, AlertDescription } from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import {
  PurchaseOrderForm,
  type PurchaseOrderFormValues,
} from '../../../../../components/spree/purchase-order-form'
import { usePurchaseOrder, useUpdatePurchaseOrder } from '../../../../../hooks/use-purchase-orders'

export const Route = createFileRoute(
  '/_authenticated/$storeId/purchase-orders/$purchaseOrderId/edit',
)({
  component: EditPurchaseOrderPage,
})

function EditPurchaseOrderPage() {
  const { t } = useTranslation()
  const { storeId, purchaseOrderId } = Route.useParams()
  const navigate = useNavigate()
  const { data: purchaseOrder, isLoading } = usePurchaseOrder(purchaseOrderId)
  const updateMutation = useUpdatePurchaseOrder(purchaseOrderId)

  const backToOrder = () =>
    navigate({
      to: '/$storeId/purchase-orders/$purchaseOrderId',
      params: { storeId, purchaseOrderId },
    })

  if (isLoading || !purchaseOrder) {
    return <div className="p-4 text-muted-foreground text-sm">{t('admin.common.loading')}</div>
  }

  // The endpoint refuses the write once the order has gone to the supplier, so
  // the screen says so rather than offering a form whose Save cannot succeed.
  // Reachable by URL even though the header hides the button by then.
  if (!purchaseOrder.editable) {
    return (
      <div className="flex flex-col gap-6">
        <PageHeader
          title={t('admin.purchase_orders.edit_title', { number: purchaseOrder.number })}
          backTo={`purchase-orders/${purchaseOrderId}`}
        />
        <Alert>
          <AlertDescription>{t('admin.purchase_orders.errors.not_editable')}</AlertDescription>
        </Alert>
      </div>
    )
  }

  async function handleSubmit(values: PurchaseOrderFormValues) {
    const saved = await updateMutation
      .mutateAsync({
        supplier_id: values.supplierId,
        destination_location_id: values.destinationId,
        // Cleared rather than omitted: an emptied field has to survive the
        // round trip, and omitting it would leave the old value in place.
        expected_at: values.expectedAt ?? null,
        reference: values.reference.trim() || null,
        notes: values.notes.trim() || null,
        items: values.lines.map((line) => ({
          variant_id: line.variant.id,
          quantity_ordered: line.quantity,
          unit_cost: line.unitCost,
        })),
      })
      .catch(() => undefined)
    if (!saved) return

    backToOrder()
  }

  return (
    <PurchaseOrderForm
      title={t('admin.purchase_orders.edit_title', { number: purchaseOrder.number })}
      backTo={`purchase-orders/${purchaseOrderId}`}
      initial={{
        supplierId: purchaseOrder.supplier_id ?? '',
        destinationId: purchaseOrder.destination_location_id ?? '',
        currency: purchaseOrder.currency,
        expectedAt: purchaseOrder.expected_at ?? undefined,
        reference: purchaseOrder.reference ?? '',
        notes: purchaseOrder.notes ?? '',
        // The saved lines carry the same facts a search result does, under
        // their own names, plus the cost the merchant agreed.
        lines: (purchaseOrder.items ?? []).map((item) => ({
          variant: {
            id: item.variant_id ?? '',
            sku: item.variant_sku,
            product_name: item.variant_name,
            thumbnail_url: item.thumbnail_url,
          },
          quantity: item.quantity_ordered,
          unitCost: item.unit_cost ?? '0.00',
        })),
      }}
      // Every line cost is denominated in it, so changing it now would
      // silently reprice the order.
      currencyLocked
      submitLabel={t('admin.actions.save')}
      pendingLabel={t('admin.actions.saving')}
      pending={updateMutation.isPending}
      onSubmit={handleSubmit}
      onCancel={backToOrder}
    />
  )
}
