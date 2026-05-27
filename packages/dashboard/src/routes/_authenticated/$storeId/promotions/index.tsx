import type { Promotion } from '@spree/admin-sdk'
import { Button, RowActions, useConfirm, useRowClickBridge } from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { PlusIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'
import { adminClient } from '@/client'
import { Can } from '@/components/spree/can'
import { ResourceTable, resourceSearchSchema } from '@/components/spree/resource-table'
import { useDeletePromotion } from '@/hooks/use-promotions'
import { Subject } from '@/lib/permissions'
import { usePermissions } from '@/providers/permission-provider'
import '@/tables/promotions'

export const Route = createFileRoute('/_authenticated/$storeId/promotions/')({
  validateSearch: resourceSearchSchema,
  component: PromotionsPage,
})

function PromotionsPage() {
  const { t } = useTranslation()
  const search = Route.useSearch()
  const navigate = useNavigate()
  const { storeId } = Route.useParams()
  const confirm = useConfirm()
  const deleteMutation = useDeletePromotion()
  const { permissions } = usePermissions()

  function openEdit(id: string) {
    navigate({ to: '/$storeId/promotions/$promotionId', params: { storeId, promotionId: id } })
  }

  function openCreate() {
    navigate({ to: '/$storeId/promotions/new', params: { storeId } })
  }

  useRowClickBridge('data-promotion-id', openEdit)

  async function handleDelete(promotion: Promotion) {
    const ok = await confirm({
      title: t('admin.promotions.delete_confirm.title'),
      message: t('admin.promotions.delete_confirm.message', {
        name: promotion.name ?? t('admin.promotions.delete_confirm.default_name'),
      }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(promotion.id).catch(() => undefined)
  }

  return (
    <ResourceTable<Promotion>
      tableKey="promotions"
      queryKey="promotions"
      queryFn={(params) => adminClient.promotions.list(params)}
      searchParams={search}
      rowActions={(promotion) => (
        <RowActions
          actions={[
            { key: 'edit', onSelect: () => openEdit(promotion.id) },
            {
              key: 'delete',
              destructive: true,
              visible: permissions.can('destroy', Subject.Promotion),
              disabled: deleteMutation.isPending,
              onSelect: () => handleDelete(promotion),
            },
          ]}
        />
      )}
      actions={
        <Can I="create" a={Subject.Promotion}>
          <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
            <PlusIcon className="size-4" />
            {t('admin.pages.promotions.new_title')}
          </Button>
        </Can>
      }
    />
  )
}
