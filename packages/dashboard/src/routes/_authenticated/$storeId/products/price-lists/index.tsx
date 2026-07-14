import type { PriceList } from '@spree/admin-sdk'
import {
  adminClient,
  Can,
  ResourceTable,
  resourceSearchSchema,
  Subject,
  usePermissions,
} from '@spree/dashboard-core'
import { Button, RowActions, useConfirm, useRowClickBridge } from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { PlusIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { useDeletePriceList } from '../../../../../hooks/use-price-lists'
import '../../../../../tables/price-lists'

export const Route = createFileRoute('/_authenticated/$storeId/products/price-lists/')({
  validateSearch: resourceSearchSchema,
  component: PriceListsPage,
})

function PriceListsPage() {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const search = Route.useSearch()
  const navigate = useNavigate()
  const confirm = useConfirm()
  const deleteMutation = useDeletePriceList()
  const { permissions } = usePermissions()

  function openEdit(id: string) {
    navigate({
      to: '/$storeId/products/price-lists/$priceListId',
      params: { storeId, priceListId: id },
    })
  }

  function openCreate() {
    navigate({ to: '/$storeId/products/price-lists/new', params: { storeId } })
  }

  useRowClickBridge('data-price-list-id', openEdit)

  async function handleDelete(list: PriceList) {
    const ok = await confirm({
      title: t('admin.pages.products.price_lists.delete_confirm.title'),
      message: t('admin.pages.products.price_lists.delete_confirm.message', { name: list.name }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    try {
      await deleteMutation.mutateAsync(list.id)
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t('admin.errors.failed_to_delete'))
    }
  }

  return (
    <ResourceTable<PriceList>
      tableKey="price-lists"
      queryKey="price-lists"
      queryFn={(params) => adminClient.priceLists.list(params)}
      searchParams={search}
      rowActions={(list) => (
        <RowActions
          actions={[
            { key: 'edit', onSelect: () => openEdit(list.id) },
            {
              key: 'delete',
              destructive: true,
              visible: permissions.can('destroy', Subject.PriceList),
              disabled: deleteMutation.isPending,
              onSelect: () => handleDelete(list),
            },
          ]}
        />
      )}
      actions={
        <Can I="create" a={Subject.PriceList}>
          <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
            <PlusIcon className="size-4" />
            {t('admin.pages.products.price_lists.add_cta')}
          </Button>
        </Can>
      }
      reorder={{
        onReorder: async (id, position) => {
          await adminClient.priceLists.update(id, { position })
        },
      }}
    />
  )
}
