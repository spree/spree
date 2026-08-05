import type { Collection } from '@spree/admin-sdk'
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
import { useDeleteCollection, useRepositionCollection } from '../../../../../hooks/use-collections'
import '../../../../../tables/collections'

export const Route = createFileRoute('/_authenticated/$storeId/products/collections/')({
  validateSearch: resourceSearchSchema,
  component: CollectionsPage,
})

function CollectionsPage() {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const search = Route.useSearch()
  const navigate = useNavigate()
  const confirm = useConfirm()
  const deleteMutation = useDeleteCollection()
  const repositionMutation = useRepositionCollection()
  const { permissions } = usePermissions()

  const openCollection = (collectionId: string) =>
    navigate({
      to: '/$storeId/products/collections/$collectionId',
      params: { storeId, collectionId },
    })

  useRowClickBridge('data-collection-id', openCollection)

  async function handleDelete(collection: Collection) {
    const ok = await confirm({
      title: t('admin.collections.delete_confirm.title'),
      message: t('admin.collections.delete_confirm.message', { name: collection.name ?? '' }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    // The hook toasts on success/error; the catch only swallows the rethrow so
    // the row-action callback doesn't surface an unhandled rejection.
    await deleteMutation.mutateAsync(collection.id).catch(() => undefined)
  }

  return (
    <ResourceTable<Collection>
      tableKey="collections"
      queryKey="collections"
      queryFn={(params) => adminClient.collections.list(params)}
      searchParams={search}
      rowActions={(collection) => (
        <RowActions
          actions={[
            { key: 'edit', onSelect: () => openCollection(collection.id) },
            {
              key: 'delete',
              destructive: true,
              visible: permissions.can('destroy', Subject.Collection),
              disabled: deleteMutation.isPending,
              onSelect: () => handleDelete(collection),
            },
          ]}
        />
      )}
      actions={
        <Can I="create" a={Subject.Collection}>
          <Button
            size="sm"
            className="h-[2.125rem]"
            onClick={() =>
              navigate({ to: '/$storeId/products/collections/new', params: { storeId } })
            }
          >
            <PlusIcon className="size-4" />
            {t('admin.collections.add_cta')}
          </Button>
        </Can>
      }
      // Collections are a flat acts_as_list, so reordering is a plain position
      // update — no dedicated reposition endpoint.
      reorder={{ onReorder: (id, position) => repositionMutation.mutateAsync({ id, position }) }}
    />
  )
}
