import type { Promotion } from '@spree/admin-sdk'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { PlusIcon } from 'lucide-react'
import { adminClient } from '@/client'
import { Can } from '@/components/spree/can'
import { useConfirm } from '@/components/spree/confirm-dialog'
import { ResourceTable, resourceSearchSchema } from '@/components/spree/resource-table'
import { RowActions } from '@/components/spree/row-actions'
import { useRowClickBridge } from '@/components/spree/row-click-bridge'
import { Button } from '@/components/ui/button'
import { useDeletePromotion } from '@/hooks/use-promotions'
import { Subject } from '@/lib/permissions'
import { usePermissions } from '@/providers/permission-provider'
import '@/tables/promotions'

export const Route = createFileRoute('/_authenticated/$storeId/promotions/')({
  validateSearch: resourceSearchSchema,
  component: PromotionsPage,
})

function PromotionsPage() {
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
      title: 'Delete promotion?',
      // Matches the inline copy used by the detail-page delete handler so the
      // row-actions kebab + detail-page delete share the same UX.
      message: `${promotion.name ?? 'This promotion'} will be removed permanently. Promotions referenced by completed orders cannot be deleted.`,
      variant: 'destructive',
      confirmLabel: 'Delete',
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
            New promotion
          </Button>
        </Can>
      }
    />
  )
}
