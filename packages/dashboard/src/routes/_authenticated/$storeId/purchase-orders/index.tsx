import type { PurchaseOrder } from '@spree/admin-sdk'
import {
  adminClient,
  Can,
  ResourceTable,
  resourceSearchSchema,
  Subject,
  usePermissions,
} from '@spree/dashboard-core'
import { Button, RowActions, useConfirm, useRowClickBridge } from '@spree/dashboard-ui'
import { EyeIcon, PlusIcon } from '@spree/dashboard-ui/icons'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import { useDeletePurchaseOrder } from '../../../../hooks/use-purchase-orders'
import '../../../../tables/purchase-orders'

export const Route = createFileRoute('/_authenticated/$storeId/purchase-orders/')({
  validateSearch: resourceSearchSchema,
  component: PurchaseOrdersPage,
})

function PurchaseOrdersPage() {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const search = Route.useSearch()
  const navigate = useNavigate()
  const confirm = useConfirm()
  const deleteMutation = useDeletePurchaseOrder()
  const { permissions } = usePermissions()

  function openDetail(id: string) {
    navigate({
      to: '/$storeId/purchase-orders/$purchaseOrderId',
      params: { storeId, purchaseOrderId: id },
    })
  }

  function openCreate() {
    navigate({ to: '/$storeId/purchase-orders/new', params: { storeId } })
  }

  useRowClickBridge('data-purchase-order-id', openDetail)

  async function handleDelete(purchaseOrder: PurchaseOrder) {
    const ok = await confirm({
      title: t('admin.purchase_orders.delete_confirm.title'),
      message: t('admin.purchase_orders.delete_confirm.message', { number: purchaseOrder.number }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(purchaseOrder.id).catch(() => undefined)
  }

  return (
    <ResourceTable<PurchaseOrder>
      tableKey="purchase-orders"
      queryKey="purchase-orders"
      queryFn={(params) => adminClient.purchaseOrders.list({ ...params, expand: ['supplier'] })}
      searchParams={search}
      rowActions={(purchaseOrder) => (
        <RowActions
          actions={[
            {
              key: 'view',
              label: t('admin.actions.view_details'),
              icon: <EyeIcon className="size-4" />,
              onSelect: () => openDetail(purchaseOrder.id),
            },
            {
              key: 'delete',
              destructive: true,
              // A placed order is a matter of record with the supplier; the
              // detail page cancels it instead.
              visible:
                purchaseOrder.status === 'draft' &&
                permissions.can('destroy', Subject.PurchaseOrder),
              disabled: deleteMutation.isPending,
              onSelect: () => handleDelete(purchaseOrder),
            },
          ]}
        />
      )}
      actions={
        <Can I="create" a={Subject.PurchaseOrder}>
          <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
            <PlusIcon className="size-4" />
            {t('admin.purchase_orders.new_cta')}
          </Button>
        </Can>
      }
    />
  )
}
