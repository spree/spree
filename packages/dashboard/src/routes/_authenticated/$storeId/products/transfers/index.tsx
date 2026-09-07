import type { StockTransfer } from '@spree/admin-sdk'
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
import { useDeleteStockTransfer } from '../../../../../hooks/use-stock-transfers'
import '../../../../../tables/stock-transfers'

export const Route = createFileRoute('/_authenticated/$storeId/products/transfers/')({
  validateSearch: resourceSearchSchema,
  component: StockTransfersPage,
})

function StockTransfersPage() {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const search = Route.useSearch()
  const navigate = useNavigate()
  const confirm = useConfirm()
  const deleteMutation = useDeleteStockTransfer()
  const { permissions } = usePermissions()

  function openDetail(id: string) {
    navigate({
      to: '/$storeId/products/transfers/$transferId',
      params: { storeId, transferId: id },
    })
  }

  function openCreate() {
    navigate({ to: '/$storeId/products/transfers/new', params: { storeId } })
  }

  useRowClickBridge('data-stock-transfer-id', openDetail)

  async function handleDelete(transfer: StockTransfer) {
    const ok = await confirm({
      title: t('admin.stock_transfers.delete_confirm.title'),
      message: t('admin.stock_transfers.delete_confirm.message', { number: transfer.number }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(transfer.id).catch(() => undefined)
  }

  return (
    <ResourceTable<StockTransfer>
      tableKey="stock-transfers"
      queryKey="stock-transfers"
      queryFn={(params) => adminClient.stockTransfers.list(params)}
      searchParams={search}
      rowActions={(transfer) => (
        <RowActions
          actions={[
            {
              key: 'view',
              label: t('admin.actions.view_details'),
              icon: <EyeIcon className="size-4" />,
              onSelect: () => openDetail(transfer.id),
            },
            {
              key: 'delete',
              destructive: true,
              // Only a draft can be thrown away: past that the transfer
              // describes a box that physically exists, and the detail page
              // cancels it instead.
              visible:
                transfer.status === 'draft' && permissions.can('destroy', Subject.StockTransfer),
              disabled: deleteMutation.isPending,
              onSelect: () => handleDelete(transfer),
            },
          ]}
        />
      )}
      actions={
        <Can I="create" a={Subject.StockTransfer}>
          <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
            <PlusIcon className="size-4" />
            {t('admin.stock_transfers.new_cta')}
          </Button>
        </Can>
      }
    />
  )
}
