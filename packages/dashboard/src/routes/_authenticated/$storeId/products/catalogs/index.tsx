import type { Catalog } from '@spree/admin-sdk'
import {
  adminClient,
  Can,
  ResourceTable,
  resourceSearchSchema,
  Subject,
  usePermissions,
} from '@spree/dashboard-core'
import { Button, RowActions, useConfirm, useRowClickBridge } from '@spree/dashboard-ui'
import { PlusIcon } from '@spree/dashboard-ui/icons'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import { useDeleteCatalog } from '../../../../../hooks/use-catalogs'
import '../../../../../tables/catalogs'

/** Catalogs list: assortments and their audiences, under Products. */
export const Route = createFileRoute('/_authenticated/$storeId/products/catalogs/')({
  validateSearch: resourceSearchSchema,
  component: CatalogsPage,
})

function CatalogsPage() {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const search = Route.useSearch()
  const navigate = useNavigate()
  const confirm = useConfirm()
  const deleteMutation = useDeleteCatalog()
  const { permissions } = usePermissions()

  function openEdit(id: string) {
    navigate({
      to: '/$storeId/products/catalogs/$catalogId',
      params: { storeId, catalogId: id },
    })
  }

  useRowClickBridge('data-catalog-id', openEdit)

  async function handleDelete(catalog: Catalog) {
    const ok = await confirm({
      title: t('admin.catalogs.delete_confirm.title'),
      message: t('admin.catalogs.delete_confirm.message', { name: catalog.name }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(catalog.id).catch(() => undefined)
  }

  return (
    <ResourceTable<Catalog>
      tableKey="catalogs"
      queryKey="catalogs"
      queryFn={(params) => adminClient.catalogs.list(params)}
      searchParams={search}
      rowActions={(catalog) => (
        <RowActions
          actions={[
            { key: 'edit', onSelect: () => openEdit(catalog.id) },
            {
              key: 'delete',
              destructive: true,
              visible: permissions.can('destroy', Subject.Catalog),
              disabled: deleteMutation.isPending,
              onSelect: () => handleDelete(catalog),
            },
          ]}
        />
      )}
      actions={
        <Can I="create" a={Subject.Catalog}>
          <Button
            size="sm"
            className="h-[2.125rem]"
            onClick={() => navigate({ to: '/$storeId/products/catalogs/new', params: { storeId } })}
          >
            <PlusIcon className="size-4" />
            {t('admin.catalogs.add_cta')}
          </Button>
        </Can>
      }
      // Dragging fires an update request, so offer it only to callers who
      // may actually update — otherwise the row moves and springs back on
      // the 403.
      reorder={
        permissions.can('update', Subject.Catalog)
          ? {
              onReorder: async (id, position) => {
                await adminClient.catalogs.update(id, { position })
              },
            }
          : undefined
      }
    />
  )
}
